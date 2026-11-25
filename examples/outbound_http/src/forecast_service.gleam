//// The client of the forecast service. Each function takes the base
//// request of the service as its first parameter, and returns a
//// `ForecastError` that says what went wrong.

import dream_http_client/client.{type ClientRequest, type StreamFailure}
import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder.{type Yielder}

pub type Forecast {
  Forecast(city: String, high: Int, low: Int)
}

pub type Watch {
  Watch(id: String, city: String)
}

pub type ForecastError {
  /// The service does not know the city: it answered 404.
  UnknownCity(city: String)
  /// The service did not answer in time.
  NoAnswerInTime(timeout_ms: Int)
  /// Any other failure: a status of 500, no connection, a body that is
  /// not the JSON we expect.
  ServiceFailed(reason: String)
}

/// The base request of the forecast service. Each call waits at most 1
/// second for a connection, and at most 2 seconds for the answer.
pub fn base_request(
  scheme: http.Scheme,
  host: String,
  port: Int,
) -> ClientRequest {
  client.new()
  |> client.scheme(scheme)
  |> client.host(host)
  |> client.port(port)
  |> client.connect_timeout(1000)
  |> client.timeout(2000)
  |> client.add_header("accept", "application/json")
}

/// The forecast of `city`, from `GET /v1/forecasts/<city>`.
pub fn get_forecast(
  service: ClientRequest,
  city: String,
) -> Result(Forecast, ForecastError) {
  use response <- result.try(
    service
    |> client.path("/v1/forecasts/" <> city)
    |> client.send()
    |> result.map_error(send_error_to_forecast_error(_, city)),
  )
  decode_body(response.body, forecast_decoder())
}

/// Asks the service to watch `city`, with `POST /v1/watches` and the
/// JSON `{"city": city}`.
pub fn watch_city(
  service: ClientRequest,
  city: String,
) -> Result(Watch, ForecastError) {
  let body = json.object([#("city", json.string(city))]) |> json.to_string
  use response <- result.try(
    service
    |> client.method(http.Post)
    |> client.path("/v1/watches")
    |> client.add_header("content-type", "application/json")
    |> client.body(body)
    |> client.send()
    |> result.map_error(send_error_to_forecast_error(_, city)),
  )
  decode_body(response.body, watch_decoder())
}

/// The hourly forecast of `city`, from `GET /v1/forecasts/<city>/hourly`,
/// chunk by chunk as the service sends it. The first chunk tells if the
/// service answered, so a 404 or a timeout is an `Error` here, before the
/// status of our own response goes out.
pub fn stream_hourly(
  service: ClientRequest,
  city: String,
) -> Result(Yielder(BitArray), ForecastError) {
  let chunks =
    service
    |> client.path("/v1/forecasts/" <> city <> "/hourly")
    |> client.stream_yielder()
  case yielder.step(chunks) {
    yielder.Next(Ok(first), rest) ->
      Ok(
        yielder.single(Ok(first))
        |> yielder.append(rest)
        |> yielder.map(chunk_or_failure_line),
      )
    yielder.Next(Error(failure), _rest) ->
      Error(stream_failure_to_forecast_error(failure, city))
    yielder.Done -> Ok(yielder.empty())
  }
}

// After the first chunk, our status is already sent. A failure can only
// end the stream with a line that says what went wrong.
fn chunk_or_failure_line(chunk: Result(BytesTree, StreamFailure)) -> BitArray {
  case chunk {
    Ok(bytes) -> bytes_tree.to_bit_array(bytes)
    Error(failure) -> <<
      "The forecast service failed: ":utf8,
      client.stream_failure_to_string(failure):utf8,
      "\n":utf8,
    >>
  }
}

fn send_error_to_forecast_error(
  error: client.SendError,
  city: String,
) -> ForecastError {
  case error {
    client.ResponseError(response:) ->
      status_to_forecast_error(response.status, city)
    client.RequestError(error:) -> transport_error_to_forecast_error(error)
  }
}

fn stream_failure_to_forecast_error(
  failure: StreamFailure,
  city: String,
) -> ForecastError {
  case failure {
    client.HttpFailure(response:) ->
      status_to_forecast_error(response.status, city)
    client.TransportFailure(error:) -> transport_error_to_forecast_error(error)
  }
}

fn status_to_forecast_error(status: Int, city: String) -> ForecastError {
  case status {
    404 -> UnknownCity(city)
    _ -> ServiceFailed("HTTP " <> int.to_string(status))
  }
}

fn transport_error_to_forecast_error(
  error: client.TransportError,
) -> ForecastError {
  case error {
    client.TimedOut(timeout_ms:) -> NoAnswerInTime(timeout_ms)
    _ -> ServiceFailed(client.transport_error_to_string(error))
  }
}

fn decode_body(
  body: BitArray,
  decoder: Decoder(a),
) -> Result(a, ForecastError) {
  json.parse_bits(body, decoder)
  |> result.map_error(fn(error) { ServiceFailed(describe_json_error(error)) })
}

fn describe_json_error(error: json.DecodeError) -> String {
  case error {
    json.UnableToDecode(errors) ->
      errors |> list.map(describe_decode_error) |> string.join("; ")
    json.UnexpectedEndOfInput -> "The JSON ends too soon"
    json.UnexpectedByte(byte) -> "The JSON has the byte " <> byte
    json.UnexpectedSequence(sequence) -> "The JSON has " <> sequence
  }
}

fn describe_decode_error(error: decode.DecodeError) -> String {
  "Expected "
  <> error.expected
  <> " at "
  <> string.join(error.path, ".")
  <> ", found "
  <> error.found
}

fn forecast_decoder() -> Decoder(Forecast) {
  use city <- decode.field("city", decode.string)
  use high <- decode.field("high", decode.int)
  use low <- decode.field("low", decode.int)
  decode.success(Forecast(city:, high:, low:))
}

fn watch_decoder() -> Decoder(Watch) {
  use id <- decode.field("id", decode.string)
  use city <- decode.field("city", decode.string)
  decode.success(Watch(id:, city:))
}
