//// Recording Response Transformers (Secret Scrubbing)
////
//// Example snippet showing how to scrub secrets from recorded responses before
//// they are written to disk.

import dream_http_client/recorder.{directory, mode, response_transformer, start}
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import simplifile

fn is_not_set_cookie(header: #(String, String)) -> Bool {
  header.0 != "set-cookie"
}

fn scrub_response(
  _request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  case response {
    recording.BlockingResponse(status, headers, _body) ->
      recording.BlockingResponse(
        status: status,
        headers: list.filter(headers, is_not_set_cookie),
        body: "",
      )

    recording.StreamingResponse(status, headers, chunks) ->
      recording.StreamingResponse(
        status: status,
        headers: list.filter(headers, is_not_set_cookie),
        chunks: chunks,
      )
  }
}

pub fn response_transformer_scrubs_before_persistence() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_response_transformer_snippet"

  let _ = simplifile.delete(recordings_directory_path)

  use record_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> response_transformer(scrub_response)
    |> start(),
  )

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

  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [#("set-cookie", "secret_cookie=abc123")],
      body: "SECRET_BODY",
    )

  recorder.add_recording(
    record_recorder,
    recording.Recording(request: request, response: response),
  )

  let _ = recorder.stop(record_recorder)

  use loaded <- result.try(storage.load_recordings(recordings_directory_path))
  use first <- result.try(
    list.first(loaded)
    |> result.map_error(fn(_) { "Expected at least one persisted recording" }),
  )

  let _ = simplifile.delete(recordings_directory_path)

  case first.response {
    recording.BlockingResponse(_status, headers, body) -> {
      let has_set_cookie = list.any(headers, fn(h) { h.0 == "set-cookie" })
      Ok(!has_set_cookie && body == "")
    }
    _ -> Error("Expected BlockingResponse")
  }
}
