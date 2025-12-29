import dream_http_client/matching
import dream_http_client/recorder.{
  directory, key, mode, request_transformer, start,
}
import dream_http_client/recording
import dream_http_client/storage
import gleam/erlang/process
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn temp_directory(label: String) -> String {
  "/tmp/dream_http_client_transformer_"
  <> label
  <> "_"
  <> string.inspect(get_timestamp())
}

fn scrub_auth_and_body(
  req: recording.RecordedRequest,
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
  ) = req
  let headers2 = list.filter(headers, fn(h) { h.0 != "Authorization" })
  recording.RecordedRequest(
    method: method,
    scheme: scheme,
    host: host,
    port: port,
    path: path,
    query: query,
    headers: headers2,
    body: "",
  )
}

pub fn transformer_is_applied_before_keying_and_persistence_test() {
  let recordings_directory_path = temp_directory("scrub")
  let request_key_fn =
    matching.request_key(method: True, url: True, headers: True, body: True)

  // Record a recording with secrets
  let request_with_secret =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("Authorization", "Bearer secret"), #("X-Ok", "1")],
      body: "{\"secret\":\"value\"}",
    )

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "OK")

  let rec_entry =
    recording.Recording(request: request_with_secret, response: response)

  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> key(request_key_fn)
    |> request_transformer(scrub_auth_and_body)
    |> start()

  recorder.add_recording(rec, rec_entry)
  process.sleep(100)
  let assert Ok(_) = recorder.stop(rec)

  // Persistence: stored recording should have secrets removed
  let assert Ok(loaded) = storage.load_recordings(recordings_directory_path)
  let assert Ok(first) = list.first(loaded)
  first.request.body |> should.equal("")
  list.any(first.request.headers, fn(h) { h.0 == "Authorization" })
  |> should.be_false()

  // Playback: request with different secret should still match
  let assert Ok(playback) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> key(request_key_fn)
    |> request_transformer(scrub_auth_and_body)
    |> start()

  let request_with_different_secret =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("Authorization", "Bearer different"), #("X-Ok", "1")],
      body: "{\"secret\":\"different\"}",
    )

  let found = recorder.find_recording(playback, request_with_different_secret)

  case found {
    Ok(option.Some(_)) -> Nil
    Ok(option.None) -> should.fail()
    Error(reason) -> {
      // Should not be ambiguous; expect a match
      let _unused = reason
      should.fail()
    }
  }

  recorder.stop(playback) |> result.unwrap(Nil)
}
