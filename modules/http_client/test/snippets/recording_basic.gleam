//// Recording and Playback
////
//// Example snippet showing how to record and playback HTTP requests.
////
//// Note: Tests use localhost:9876 (mock server) instead of external APIs

import dream_http_client/client
import dream_http_client/matching
import dream_http_client/recorder
import gleam/http
import gleam/result
import simplifile

pub fn record_and_playback() -> Result(Bool, String) {
  let directory = "build/test_recordings_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(directory)

  // 1. Record a real request
  use rec <- result.try(recorder.start(
    recorder.Record(directory: directory),
    matching.match_url_only(),
  ))

  let request_result =
    client.new
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/text")
    |> client.recorder(rec)
    |> client.send()

  // Recording is saved immediately, stop is optional
  let _ = recorder.stop(rec)

  use original_body <- result.try(request_result)

  // 2. Playback from recording (no network call)
  use playback_rec <- result.try(recorder.start(
    recorder.Playback(directory: directory),
    matching.match_url_only(),
  ))

  let playback_result =
    client.new
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/text")
    |> client.recorder(playback_rec)
    |> client.send()

  let _ = recorder.stop(playback_rec)

  use playback_body <- result.try(playback_result)

  // Cleanup
  let _ = simplifile.delete(directory)

  // Verify bodies match
  Ok(original_body == playback_body)
}
