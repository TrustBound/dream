//// Recording and Playback with stream_yielder()
////
//// Example showing how to record a streaming response and play it back
//// using the yielder-based streaming API.
////
//// Note: Tests use localhost:9876 (mock server) instead of external APIs

import dream_http_client/client.{
  host, path, port, recorder as with_recorder, scheme, stream_yielder,
}
import dream_http_client/recorder.{directory, mode, start}
import gleam/bytes_tree
import gleam/http
import gleam/result
import gleam/yielder
import simplifile

pub fn record_and_playback_stream_yielder() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_recordings_stream_yielder_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

  // 1. Record a real streaming request
  use rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start(),
  )

  let original_bytes =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> with_recorder(rec)
    |> stream_yielder()
    |> yielder.fold(0, fn(total, chunk_result) {
      case chunk_result {
        Ok(chunk) -> total + bytes_tree.byte_size(chunk)
        Error(_) -> total
      }
    })

  let _ = recorder.stop(rec)

  case original_bytes > 0 {
    True -> Nil
    False -> panic as "No bytes received during recording"
  }

  // 2. Playback from recording (no network call)
  use playback_rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start(),
  )

  let playback_bytes =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> with_recorder(playback_rec)
    |> stream_yielder()
    |> yielder.fold(0, fn(total, chunk_result) {
      case chunk_result {
        Ok(chunk) -> total + bytes_tree.byte_size(chunk)
        Error(_) -> total
      }
    })

  let _ = recorder.stop(playback_rec)

  // Cleanup
  let _ = simplifile.delete(recordings_directory_path)

  // Verify playback returned data
  Ok(playback_bytes > 0 && playback_bytes == original_bytes)
}
