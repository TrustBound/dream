//// Recording Playback for Testing
////
//// Example showing how to use playback mode for testing without external dependencies.

import dream_http_client/client
import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import gleam/http
import gleam/option
import gleam/result

pub fn test_with_playback() -> Result(String, String) {
  // First record a request to create the fixture
  let directory = "build/test_playback_snippet"

  // Create a test recording manually
  let test_request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )

  let test_response =
    recording.BlockingResponse(status: 200, headers: [], body: "Test data")

  let test_recording =
    recording.Recording(request: test_request, response: test_response)

  // Save it
  use rec <- result.try(recorder.start(
    recorder.Record(directory: directory),
    matching.match_url_only(),
  ))

  recorder.add_recording(rec, test_recording)
  let _ = recorder.stop(rec)

  // Now use playback mode
  use playback_rec <- result.try(recorder.start(
    recorder.Playback(directory: directory),
    matching.match_url_only(),
  ))

  // Make request - returns recorded response without network call
  let result =
    client.new
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/text")
    |> client.recorder(playback_rec)
    |> client.send()

  let _ = recorder.stop(playback_rec)
  result
}
