//// File I/O for recordings
////
//// Handles loading and saving recording files to/from the filesystem.

import dream_http_client/recording
import gleam/json
import gleam/result
import gleam/string
import simplifile

/// Load recordings from a JSON file
///
/// Reads and decodes recordings from `{directory}/recordings.json`. This function
/// is used internally by the recorder when starting in Playback mode, but can also
/// be called directly to inspect or manipulate recordings.
///
/// ## Parameters
///
/// - `directory`: The directory containing the `recordings.json` file
///
/// ## Returns
///
/// - `Ok(List(Recording))`: Successfully loaded recordings (empty list if file doesn't exist)
/// - `Error(String)`: Error message if file exists but cannot be read or decoded
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
/// - Returns an empty list (not an error) if the file doesn't exist
/// - This is the expected behavior for Playback mode when no recordings have been created yet
/// - File format must match the versioned JSON structure (see `recording.RecordingFile`)
pub fn load_recordings(
  directory: String,
) -> Result(List(recording.Recording), String) {
  let file_path = build_file_path(directory)
  case simplifile.read(file_path) {
    Ok(content) -> {
      case recording.decode_recording_file(content) {
        Ok(file) -> Ok(file.entries)
        Error(reason) -> Error("Failed to decode recording file: " <> reason)
      }
    }
    Error(simplifile.Enoent) -> {
      // File doesn't exist - return empty list (not an error)
      Ok([])
    }
    Error(read_error) -> {
      Error("Failed to read recording file: " <> string.inspect(read_error))
    }
  }
}

/// Save a single recording immediately by appending to existing recordings
///
/// Loads existing recordings, prepends the new recording, and saves all.
/// This uses a read-modify-write approach that prioritizes reliability over performance.
///
/// **Performance Tradeoff:** This function performs O(n) file I/O operations where n is
/// the number of existing recordings. For typical use cases (recording once, playback often),
/// this is acceptable. If you need high-performance recording with deferred saves or delta
/// files, please create an issue at https://github.com/TrustBound/dream/issues.
pub fn save_recording_immediately(
  directory: String,
  recording: recording.Recording,
) -> Result(Nil, String) {
  use existing <- result.try(load_recordings(directory))
  save_recordings(directory, [recording, ..existing])
}

/// Save recordings to a JSON file
///
/// Writes all recordings to `{directory}/recordings.json` in the versioned JSON format.
/// Creates the directory if it doesn't exist. This function overwrites any existing
/// recordings file.
///
/// ## Parameters
///
/// - `directory`: The directory where `recordings.json` will be written
/// - `recordings`: List of recordings to save
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
///
/// case storage.save_recordings("mocks/api", recordings) {
///   Ok(_) -> io.println("Saved recordings successfully")
///   Error(reason) -> io.println_error("Failed to save: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Directory is created automatically if it doesn't exist
/// - Existing `recordings.json` file is overwritten (use `load_recordings` first to merge)
/// - File format includes version field for future compatibility
pub fn save_recordings(
  directory: String,
  recordings: List(recording.Recording),
) -> Result(Nil, String) {
  let file_path = build_file_path(directory)

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
    // Create recording file
    let recording_file =
      recording.RecordingFile(version: "1.0", entries: recordings)

    // Encode to JSON
    let json_value = recording.encode_recording_file(recording_file)
    let json_string = json.to_string(json_value)

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

fn build_file_path(directory: String) -> String {
  // Ensure directory ends with "/"
  let normalized_directory = case string.ends_with(directory, "/") {
    True -> directory
    False -> directory <> "/"
  }
  normalized_directory <> "recordings.json"
}
