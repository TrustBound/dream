//// Recording Playback for Testing
////
//// Example showing how to use playback mode for testing without external dependencies.

import dream_http_client/client.{
  host, path, port, recorder as with_recorder, scheme, send,
}
import dream_http_client/recorder.{directory, mode, start}
import dream_http_client/recording
import gleam/http
import gleam/option
import gleam/result
import simplifile

pub fn test_with_playback() -> Result(String, String) {
  // First record a request to create the fixture
  let recordings_directory_path = "build/test_playback_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

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
  use rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start(),
  )

  recorder.add_recording(rec, test_recording)
  let _ = recorder.stop(rec)

  // Now use playback mode
  use playback_rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start(),
  )

  // Make request - returns recorded response without network call
  let result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> with_recorder(playback_rec)
    |> send()

  let _ = recorder.stop(playback_rec)
  let _ = simplifile.delete(recordings_directory_path)
  result
}
