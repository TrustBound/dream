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
/// Returns an empty list if the file doesn't exist (for playback mode,
/// this means no recordings are available).
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

/// Save recordings to a JSON file
///
/// Creates the directory if it doesn't exist and writes all recordings
/// to a single JSON file.
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
  // Ensure directory ends with /
  let dir = case string.ends_with(directory, "/") {
    True -> directory
    False -> directory <> "/"
  }
  dir <> "recordings.json"
}
