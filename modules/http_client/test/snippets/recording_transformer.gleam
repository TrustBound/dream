//// Recording Transformers (Secret Scrubbing)
////
//// Example snippet showing how to use a RequestTransformer to normalize/scrub
//// requests (e.g. remove Authorization headers) before keying + persistence.

import dream_http_client/matching
import dream_http_client/recorder.{
  directory, key, mode, request_transformer, start,
}
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import simplifile

fn is_authorization_header(header: #(String, String)) -> Bool {
  header.0 == "Authorization"
}

fn is_not_authorization_header(header: #(String, String)) -> Bool {
  !is_authorization_header(header)
}

fn expected_non_empty_list_error(_ignored: Nil) -> String {
  "Expected at least one persisted recording"
}

pub fn scrub_auth_and_body(
  request: recording.RecordedRequest,
) -> recording.RecordedRequest {
  let recording.RecordedRequest(
    method,
    scheme,
    host,
    port,
    path,
    query,
    headers,
    _body,
  ) = request

  let scrubbed_headers = list.filter(headers, is_not_authorization_header)

  recording.RecordedRequest(
    method: method,
    scheme: scheme,
    host: host,
    port: port,
    path: path,
    query: query,
    headers: scrubbed_headers,
    body: "",
  )
}

fn error_with_cleanup(
  recordings_directory_path: String,
  message: String,
) -> Result(a, String) {
  let _ = simplifile.delete(recordings_directory_path)
  Error(message)
}

pub fn transformer_scrubs_and_still_matches() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_transformer_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

  let request_key_fn =
    matching.request_key(method: True, url: True, headers: True, body: True)

  // Record a recording with secrets
  use record_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> key(request_key_fn)
    |> request_transformer(scrub_auth_and_body)
    |> start(),
  )

  let request_with_secret =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [#("Authorization", "Bearer secret"), #("X-Ok", "1")],
      body: "{\"secret\":\"value\"}",
    )

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "OK")

  let entry =
    recording.Recording(request: request_with_secret, response: response)

  recorder.add_recording(record_recorder, entry)
  let _ = recorder.stop(record_recorder)

  // Verify persisted recording has secrets scrubbed
  use loaded <- result.try(storage.load_recordings(recordings_directory_path))
  use first <- result.try(
    list.first(loaded)
    |> result.map_error(expected_non_empty_list_error),
  )

  use _ <- result.try(case first.request.body == "" {
    True -> Ok(Nil)
    False ->
      error_with_cleanup(
        recordings_directory_path,
        "Expected body to be scrubbed before persistence",
      )
  })

  use _ <- result.try(
    case list.any(first.request.headers, is_authorization_header) {
      True ->
        error_with_cleanup(
          recordings_directory_path,
          "Expected Authorization header to be scrubbed before persistence",
        )
      False -> Ok(Nil)
    },
  )

  // Playback: a request with different secrets should still match
  use playback_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> key(request_key_fn)
    |> request_transformer(scrub_auth_and_body)
    |> start(),
  )

  let request_with_different_secret =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [#("Authorization", "Bearer different"), #("X-Ok", "1")],
      body: "{\"secret\":\"different\"}",
    )

  let found =
    recorder.find_recording(playback_recorder, request_with_different_secret)

  let _ = recorder.stop(playback_recorder)
  let _ = simplifile.delete(recordings_directory_path)

  case found {
    Ok(option.Some(_)) -> Ok(True)
    Ok(option.None) -> Error("Expected playback to match after scrubbing")
    Error(reason) -> Error(reason)
  }
}
