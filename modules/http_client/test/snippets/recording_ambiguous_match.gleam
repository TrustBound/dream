//// Recording Ambiguous Match (Collision) Behavior
////
//// Example snippet showing that playback errors if multiple recordings match
//// the same request key. This forces you to refine your key function.

import dream_http_client/matching
import dream_http_client/recorder.{directory, key, mode, start}
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/option
import gleam/result
import gleam/string
import simplifile

pub fn ambiguous_playback_returns_error() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_ambiguous_recordings_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

  let request_key_fn =
    matching.request_key(method: True, url: True, headers: False, body: False)

  let request =
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

  let recording_one =
    recording.Recording(
      request: request,
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "one",
      ),
    )

  let recording_two =
    recording.Recording(
      request: request,
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "two",
      ),
    )

  // Persist two recordings that share the same key
  use _ <- result.try(storage.save_recording_immediately(
    recordings_directory_path,
    recording_one,
    request_key_fn(request),
  ))

  use _ <- result.try(storage.save_recording_immediately(
    recordings_directory_path,
    recording_two,
    request_key_fn(request),
  ))

  // Playback should now error on lookup due to ambiguity
  use playback_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> key(request_key_fn)
    |> start(),
  )

  let found = recorder.find_recording(playback_recorder, request)

  let _ = recorder.stop(playback_recorder)
  let _ = simplifile.delete(recordings_directory_path)

  case found {
    Error(reason) -> {
      case string.contains(reason, "Ambiguous recording match") {
        True -> Ok(True)
        False -> Error(reason)
      }
    }
    Ok(_) -> Error("Expected playback to error due to ambiguous match")
  }
}
