//// README: Scrubbing Secrets (Transformers)
////
//// A request transformer removes the Authorization header and the body
//// before the key is computed and before the recording is saved.

import dream_http_client/matching
import dream_http_client/recorder.{
  type Recorder, directory, key, mode, request_transformer, start,
}
import dream_http_client/recording
import gleam/list

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

fn is_not_authorization_header(header: #(String, String)) -> Bool {
  header.0 != "Authorization"
}

// Requests recorded through this recorder have their secrets scrubbed
pub fn start_scrubbing_recorder(
  recordings_directory: String,
) -> Result(Recorder, String) {
  let request_key_fn =
    matching.request_key(method: True, url: True, headers: True, body: True)

  recorder.new()
  |> directory(recordings_directory)
  |> mode("record")
  |> key(request_key_fn)
  |> request_transformer(scrub_auth_and_body)
  |> start()
}
