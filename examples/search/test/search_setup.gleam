//// The setup and the teardown of the notes suites: the services of the
//// app, with a recorder on the base request of the OpenSearch client.

import app_request
import dream/http/request.{Post}
import dream_http_client/client as http_client
import dream_http_client/matching
import dream_http_client/recorder.{type Recorder}
import dream_http_client/recording.{
  type RecordedRequest, type RecordedResponse, BlockingResponse,
  StreamingResponse,
}
import dream_opensearch/client
import envoy
import gleam/bit_array
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import notes/search_index
import notes/services.{type Services}

/// What each notes test gets: the services of the app, and the recorder
/// in them when the suite has one.
pub type App {
  App(services: Services, recorder: Option(Recorder))
}

/// The port of OpenSearch in the tests. The recordings hold it, so
/// playback must use the port of the record run.
pub const opensearch_port = 19_200

/// A port where nothing listens: OpenSearch is down.
pub const closed_port = 19_299

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no OpenSearch.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}

/// Starts a recorder in `mode` that keeps its files in
/// `test/recordings/<index>`, and the services of the app with it. Then it
/// creates the index, as `main` does.
pub fn start_app(mode: recorder.Mode, index: String) -> Result(App, String) {
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/" <> index)
    |> recorder.mode(mode)
    |> recorder.key(matching.request_key(
      method: True,
      url: True,
      headers: False,
      body: True,
    ))
    |> recorder.response_transformer(drop_timings)
    |> recorder.start(),
  )
  let opensearch =
    http_client.new()
    |> http_client.scheme(http.Http)
    |> http_client.host("localhost")
    |> http_client.port(opensearch_port)
    |> http_client.recorder(recorder)
    |> client.from_request
  use services <- result.try(services.start_services(opensearch, index))
  use Nil <- result.try(
    search_index.ensure_index(services.opensearch, services.index)
    |> result.map_error(client.describe_error),
  )
  Ok(App(services:, recorder: Some(recorder)))
}

/// The services of the app with OpenSearch down: the base request points
/// at a port where nothing listens.
pub fn start_app_without_search() -> Result(App, String) {
  let opensearch =
    http_client.new()
    |> http_client.scheme(http.Http)
    |> http_client.host("localhost")
    |> http_client.port(closed_port)
    |> client.from_request
  use services <- result.try(services.start_services(opensearch, "notes"))
  Ok(App(services:, recorder: None))
}

pub fn stop_app(app: App) -> Result(Nil, String) {
  services.stop_services(app.services)
  case app.recorder {
    Some(recorder) -> recorder.stop(recorder)
    None -> Ok(Nil)
  }
}

/// Adds a note through the routes of the app
pub fn add_note(app: App, title: String, body: String) -> Result(Nil, String) {
  let body = "{\"title\":\"" <> title <> "\",\"body\":\"" <> body <> "\"}"
  case
    app_request.answer(app_request.send(app.services, Post, "/notes", "", body))
  {
    #(201, _note) -> Ok(Nil)
    other -> Error("POST /notes should answer 201: " <> string.inspect(other))
  }
}

/// OpenSearch makes a new document searchable about one time each second.
/// A test that searches right after a write asks for a refresh first.
pub fn refresh(app: App) -> Result(Nil, String) {
  client.send_request(
    app.services.opensearch,
    http.Post,
    "/" <> app.services.index <> "/_refresh",
    "",
  )
  |> result.replace(Nil)
  |> result.map_error(client.describe_error)
}

/// Runs in record mode only, before the recorder writes the response.
/// `took` is the time of the request in OpenSearch, and the `date` header
/// is the time of the answer. Both change on each run, so this sets `took`
/// to 0 and removes `date`. The body length changes with `took`, so it
/// removes `content-length` too. A new record run then gives the same
/// files.
fn drop_timings(
  _request: RecordedRequest,
  response: RecordedResponse,
) -> RecordedResponse {
  let keep = fn(header: #(String, String)) {
    header.0 != "date" && header.0 != "content-length"
  }
  case response {
    BlockingResponse(..) ->
      BlockingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
        body: zero_took(response.body),
      )
    StreamingResponse(..) ->
      StreamingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
      )
  }
}

fn zero_took(body: BitArray) -> BitArray {
  bit_array.to_string(body)
  |> result.map(fn(text) { bit_array.from_string(zero_took_text(text)) })
  |> result.unwrap(body)
}

fn zero_took_text(text: String) -> String {
  case string.split_once(text, "\"took\":") {
    Ok(#(before, after)) ->
      before <> "\"took\":0" <> string.drop_start(after, count_digits(after))
    Error(Nil) -> text
  }
}

fn count_digits(text: String) -> Int {
  text
  |> string.to_graphemes
  |> list.take_while(fn(character) { string.contains("0123456789", character) })
  |> list.length
}
