import dream_http_client/recorder.{directory, mode, response_transformer, start}
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import simplifile

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn temp_directory(label: String) -> String {
  "/tmp/dream_http_client_response_transformer_"
  <> label
  <> "_"
  <> string.inspect(get_timestamp())
}

fn scrub_response(
  _request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  case response {
    recording.BlockingResponse(status, headers, _body) ->
      recording.BlockingResponse(
        status: status,
        headers: list.filter(headers, fn(h) { h.0 != "set-cookie" }),
        body: "",
      )
    recording.StreamingResponse(status, headers, chunks) ->
      recording.StreamingResponse(
        status: status,
        headers: list.filter(headers, fn(h) { h.0 != "set-cookie" }),
        chunks: chunks,
      )
  }
}

pub fn response_transformer_is_applied_before_persistence_test() {
  let recordings_directory_path = temp_directory("scrub_response")

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

  let entry = recording.Recording(request: request, response: response)

  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> response_transformer(scrub_response)
    |> start()

  recorder.add_recording(rec, entry)
  recorder.stop(rec) |> result.unwrap(Nil)

  let assert Ok(loaded) = storage.load_recordings(recordings_directory_path)
  let assert Ok(first) = list.first(loaded)

  case first.response {
    recording.BlockingResponse(_status, headers, body) -> {
      list.any(headers, fn(h) { h.0 == "set-cookie" })
      |> should.be_false()
      body |> should.equal("")
    }
    _ -> should.fail()
  }

  let _ = simplifile.delete(recordings_directory_path)
}
