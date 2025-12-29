//// Recording and Playback
////
//// Example snippet showing how to record and playback HTTP requests.
////
//// Note: Tests use localhost:9876 (mock server) instead of external APIs

import dream_http_client/client.{
  host, path, port, recorder as with_recorder, scheme, send,
}
import dream_http_client/recorder.{directory, mode, start}
import gleam/http
import gleam/result
import simplifile

pub fn record_and_playback() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_recordings_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

  // 1. Record a real request
  use rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start(),
  )

  let request_result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> with_recorder(rec)
    |> send()

  // Recording is saved immediately, stop is optional
  let _ = recorder.stop(rec)

  use original_body <- result.try(request_result)

  // 2. Playback from recording (no network call)
  use playback_rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start(),
  )

  let playback_result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> with_recorder(playback_rec)
    |> send()

  let _ = recorder.stop(playback_rec)

  use playback_body <- result.try(playback_result)

  // Cleanup
  let _ = simplifile.delete(recordings_directory_path)

  // Verify bodies match
  Ok(original_body == playback_body)
}
