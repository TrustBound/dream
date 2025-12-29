//// File I/O for recordings
////
//// Handles loading and saving recording files to/from the filesystem.

import dream_http_client/matching
import dream_http_client/recording
import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import simplifile

/// Load recordings from a directory
///
/// Scans the directory for all `.json` files and loads them as individual recordings.
/// This function is used internally by the recorder when starting in Playback mode, but
/// can also be called directly to inspect or manipulate recordings.
///
/// ## Parameters
///
/// - `directory`: The directory containing individual recording files
///
/// ## Returns
///
/// - `Ok(List(Recording))`: Successfully loaded recordings (empty list if directory doesn't exist)
/// - `Error(String)`: Error message if directory exists but files cannot be read or decoded
///
/// ## Examples
///
/// ```gleam
/// // Load recordings for inspection
/// case storage.load_recordings("mocks/api") {
///   Ok(recordings) -> {
///     io.println("Loaded " <> int.to_string(list.length(recordings)) <> " recordings")
///   }
///   Error(reason) -> io.println_error("Failed to load: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Returns an empty list (not an error) if the directory doesn't exist
/// - This is the expected behavior for Playback mode when no recordings have been created yet
/// - Each file contains a single recording in the versioned JSON format
pub fn load_recordings(
  directory: String,
) -> Result(List(recording.Recording), String) {
  // List all .json files in directory
  case simplifile.read_directory(directory) {
    Ok(files) -> {
      // Filter for .json files
      let json_files =
        list.filter(files, fn(file) { string.ends_with(file, ".json") })

      // Load each file
      json_files
      |> list.try_map(fn(filename) {
        let file_path = directory <> "/" <> filename
        case simplifile.read(file_path) {
          Ok(content) -> {
            case recording.decode_recording_file(content) {
              Ok(file) -> {
                // Extract first entry (should only be one per file)
                case list.first(file.entries) {
                  Ok(entry) -> Ok(entry)
                  Error(_) ->
                    Error("Recording file contains no entries: " <> file_path)
                }
              }
              Error(reason) ->
                Error("Failed to decode " <> file_path <> ": " <> reason)
            }
          }
          Error(read_error) ->
            Error(
              "Failed to read "
              <> file_path
              <> ": "
              <> string.inspect(read_error),
            )
        }
      })
    }
    Error(simplifile.Enoent) -> {
      // Directory doesn't exist - return empty list (not an error)
      Ok([])
    }
    Error(read_error) -> {
      Error(
        "Failed to read directory "
        <> directory
        <> ": "
        <> string.inspect(read_error),
      )
    }
  }
}

/// Save a single recording immediately to its own file
///
/// Writes a single recording to an individual file.
///
/// The filename includes human-readable parts (method/host/path) plus a short
/// hash of the **match key** and a short hash of the **file content**. This
/// avoids overwriting when multiple recordings share the same key.
///
/// ## Parameters
///
/// - `directory`: The directory where the recording file will be written
/// - `rec`: The recording to save
/// - `key`: The match key string for this request (should match the recorder's key function)
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully saved the recording
/// - `Error(String)`: Error message if directory creation or file write fails
///
/// ## Examples
///
/// ```gleam
/// let rec = recording.Recording(request: req, response: resp)
///
/// // Compute a key string using the same key policy you use for playback:
/// let key_fn = matching.request_key(method: True, url: True, headers: False, body: False)
/// let key = key_fn(rec.request)
///
/// case storage.save_recording_immediately("mocks/api", rec, key) {
///   Ok(_) -> io.println("Saved recording")
///   Error(reason) -> io.println_error("Failed to save: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Each recording is saved to its own file for O(1) write performance
/// - Filenames include human-readable parts (method, host, path) plus a hash for uniqueness
/// - Concurrent tests can record safely without file contention
pub fn save_recording_immediately(
  directory: String,
  rec: recording.Recording,
  key: String,
) -> Result(Nil, String) {
  // Create directory if it doesn't exist
  case simplifile.create_directory_all(directory) {
    Ok(Nil) -> Ok(Nil)
    Error(simplifile.Eexist) -> {
      // Directory already exists - that's fine
      Ok(Nil)
    }
    Error(directory_error) -> {
      Error(
        "Failed to create directory "
        <> directory
        <> ": "
        <> string.inspect(directory_error),
      )
    }
  }
  |> result.try(fn(_) {
    // Create recording file with single entry
    let recording_file = recording.RecordingFile(version: "1.0", entries: [rec])

    // Encode to JSON
    let json_value = recording.encode_recording_file(recording_file)
    let json_string = json.to_string(json_value)

    // Build filename from the key + content to avoid overwriting when multiple
    // recordings share the same key (which will later be treated as ambiguous
    // during playback).
    let filename = build_filename(rec.request, key, json_string)
    let file_path = directory <> "/" <> filename

    // Write to file
    case simplifile.write(file_path, json_string) {
      Ok(Nil) -> Ok(Nil)
      Error(write_error) -> {
        Error(
          "Failed to write recording file "
          <> file_path
          <> ": "
          <> string.inspect(write_error),
        )
      }
    }
  })
}

/// Save multiple recordings to individual files
///
/// Writes each recording to its own file in the directory. Creates the directory if it
/// doesn't exist. Each file is named based on the request signature for easy identification.
///
/// ## Parameters
///
/// - `directory`: The directory where recording files will be written
/// - `recordings`: List of recordings to save
/// - `key_fn`: Match key function used to compute each recording's key string
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully saved all recordings
/// - `Error(String)`: Error message if directory creation or file write fails
///
/// ## Examples
///
/// ```gleam
/// let recordings = [
///   create_test_recording(),
///   create_another_recording(),
/// ]
/// let key_fn = matching.request_key(method: True, url: True, headers: False, body: False)
///
/// case storage.save_recordings("mocks/api", recordings, key_fn) {
///   Ok(_) -> io.println("Saved recordings successfully")
///   Error(reason) -> io.println_error("Failed to save: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Directory is created automatically if it doesn't exist
/// - Each recording is saved to its own file (no file contention)
/// - Existing files with the same name are overwritten
pub fn save_recordings(
  directory: String,
  recordings: List(recording.Recording),
  key_fn: matching.MatchKey,
) -> Result(Nil, String) {
  // Create directory if it doesn't exist
  case simplifile.create_directory_all(directory) {
    Ok(Nil) -> Ok(Nil)
    Error(simplifile.Eexist) -> {
      // Directory already exists - that's fine
      Ok(Nil)
    }
    Error(directory_error) -> {
      Error(
        "Failed to create directory "
        <> directory
        <> ": "
        <> string.inspect(directory_error),
      )
    }
  }
  |> result.try(fn(_) {
    // Save each recording to its own file
    recordings
    |> list.try_each(fn(rec) {
      let key = key_fn(rec.request)
      save_recording_immediately(directory, rec, key)
    })
  })
}

/// Build a unique filename for a recording based on the request
///
/// Creates a filename with the format:
///
/// `{method}_{host}_{path}_{key_hash}_{content_hash}.json`
///
/// - `key_hash` groups recordings by match key
/// - `content_hash` prevents overwrites when multiple recordings share the same key
///
/// ## Parameters
///
/// - `request`: The request to generate a filename for
/// - `key`: The match key string used for grouping
/// - `content`: The JSON file content (used for the content hash)
///
/// ## Returns
///
/// A safe filename string ending in `.json`
///
/// ## Examples
///
/// - `GET_api.example.com_users_a3f5b2.json`
/// - `POST_api.example.com_users_c7d8e9.json`
/// - `GET_localhost_text_f1a2b3.json`
fn build_filename(
  request: recording.RecordedRequest,
  key: String,
  content: String,
) -> String {
  // Build human-readable part from method + host + path
  let method_part = sanitize_for_filename(method_to_string(request.method))
  let host_part = sanitize_for_filename(request.host)
  let path_part =
    request.path
    |> string.replace("/", "_")
    |> sanitize_for_filename()
    |> truncate_string(50)

  // Generate hashes for uniqueness.
  // - key hash groups requests by matching key
  // - content hash differentiates multiple recordings with the same key
  let key_hash_short = string.slice(generate_hash(key), 0, 6)
  let content_hash_short = string.slice(generate_hash(content), 0, 6)

  // Combine parts
  method_part
  <> "_"
  <> host_part
  <> "_"
  <> path_part
  <> "_"
  <> key_hash_short
  <> "_"
  <> content_hash_short
  <> ".json"
}

fn method_to_string(method: http.Method) -> String {
  case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Patch -> "PATCH"
    http.Head -> "HEAD"
    http.Options -> "OPTIONS"
    http.Trace -> "TRACE"
    http.Connect -> "CONNECT"
    http.Other(s) -> string.uppercase(s)
  }
}

/// Sanitize a string to be safe for use in filenames
///
/// Replaces characters that are problematic in filenames with underscores.
/// Allows alphanumeric, hyphens, periods, and underscores.
fn sanitize_for_filename(input: String) -> String {
  input
  |> string.to_graphemes()
  |> list.map(fn(char) {
    case char {
      "a"
      | "b"
      | "c"
      | "d"
      | "e"
      | "f"
      | "g"
      | "h"
      | "i"
      | "j"
      | "k"
      | "l"
      | "m"
      | "n"
      | "o"
      | "p"
      | "q"
      | "r"
      | "s"
      | "t"
      | "u"
      | "v"
      | "w"
      | "x"
      | "y"
      | "z" -> char
      "A"
      | "B"
      | "C"
      | "D"
      | "E"
      | "F"
      | "G"
      | "H"
      | "I"
      | "J"
      | "K"
      | "L"
      | "M"
      | "N"
      | "O"
      | "P"
      | "Q"
      | "R"
      | "S"
      | "T"
      | "U"
      | "V"
      | "W"
      | "X"
      | "Y"
      | "Z" -> char
      "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> char
      "-" | "." | "_" -> char
      _ -> "_"
    }
  })
  |> string.join("")
}

/// Truncate a string to a maximum length
fn truncate_string(input: String, max_length: Int) -> String {
  case string.length(input) > max_length {
    True -> string.slice(input, 0, max_length)
    False -> input
  }
}

/// Generate a hash from a string
fn generate_hash(input: String) -> String {
  let bits = bit_array.from_string(input)
  let hash_bits = crypto.hash(crypto.Sha256, bits)
  bit_array.base16_encode(hash_bits)
  |> string.lowercase()
}
