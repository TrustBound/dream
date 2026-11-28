//// The setup and the teardown of the parcels suites: a recorder on the
//// base request of the carrier API, in the services of the app.

import dream_http_client/client
import dream_http_client/recorder.{type Recorder}
import dream_http_client/recording.{
  type RecordedRequest, type RecordedResponse, BlockingResponse, RecordedRequest,
  StreamingResponse,
}
import dream_mock_server/config.{Exact, MockRoute, Prefix}
import dream_mock_server/server.{type ServerHandle}
import envoy
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import parcels/services.{type Services, Services}

/// What each parcels test gets: the services of the app, the recorder in
/// them, and the fake carrier API when one runs.
pub type App {
  App(services: Services, recorder: Recorder, carrier: Option(ServerHandle))
}

/// The port of the carrier API in the tests. The recordings hold it, so
/// playback must use the port of the record run.
pub const carrier_port = 19_870

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no network.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}

/// Starts a recorder in `mode`, and the services of the app with it. Only
/// a run that sends requests starts the fake carrier API.
pub fn start_app(mode: recorder.Mode, port: Int) -> Result(App, String) {
  use carrier <- result.try(case mode {
    recorder.Playback -> Ok(None)
    recorder.Record | recorder.Passthrough ->
      start_fake_carrier(port)
      |> result.map(Some)
      |> result.map_error(string.inspect)
  })
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/carrier")
    |> recorder.mode(mode)
    |> recorder.request_transformer(drop_authorization)
    |> recorder.response_transformer(drop_date)
    |> recorder.start(),
  )
  let base =
    client.new()
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.add_header("authorization", "Bearer test-carrier-token")
    |> client.recorder(recorder)
  Ok(App(services: Services(carrier: base), recorder:, carrier:))
}

pub fn stop_app(app: App) -> Result(Nil, String) {
  let stopped = recorder.stop(app.recorder)
  option.map(app.carrier, server.stop)
  stopped
}

/// Runs before the recorder computes the key and before it writes the
/// file: no recording holds the token.
fn drop_authorization(request: RecordedRequest) -> RecordedRequest {
  let headers =
    list.filter(request.headers, fn(header) {
      string.lowercase(header.0) != "authorization"
    })
  RecordedRequest(..request, headers:)
}

/// Runs in record mode only, before the recorder writes the response: the
/// `date` header changes on each run, so a new record run of the same
/// answer gives the same file.
fn drop_date(
  _request: RecordedRequest,
  response: RecordedResponse,
) -> RecordedResponse {
  let keep = fn(header: #(String, String)) { header.0 != "date" }
  case response {
    BlockingResponse(..) ->
      BlockingResponse(..response, headers: list.filter(response.headers, keep))
    StreamingResponse(..) ->
      StreamingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
      )
  }
}

/// The fake carrier API of a record run: two parcels, and a 404 for the
/// rest. With the real API, leave it out and point the base request at it.
fn start_fake_carrier(port: Int) {
  server.start_with_config(port, [
    MockRoute(
      path: "/v1/parcels/PX-100",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
    ),
    MockRoute(
      path: "/v1/parcels/PX-200",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"code\":\"PX-200\",\"status\":\"delivered\",\"eta\":\"2026-11-20\"}",
    ),
    MockRoute(
      path: "/v1/parcels/",
      path_match: Prefix,
      method: None,
      status: 404,
      body: "{\"error\":\"unknown parcel\"}",
    ),
  ])
}
