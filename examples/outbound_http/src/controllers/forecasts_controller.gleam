//// The forecasts of a city, from the forecast service in services.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_string}
import dream/http/error
import dream/http/response.{json_response, stream_response}
import dream/http/status
import forecast_service.{
  type Forecast, type ForecastError, type Watch, NoAnswerInTime, ServiceFailed,
  UnknownCity,
}
import gleam/int
import gleam/json
import services.{type Services}

const bad_gateway = 502

const gateway_timeout = 504

/// GET /forecasts/:city: the forecast as JSON.
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  use city <- with_city(request)
  case forecast_service.get_forecast(services.forecasts, city) {
    Ok(forecast) -> json_response(status.ok, forecast_json(forecast))
    Error(error) -> error_response(error)
  }
}

/// POST /forecasts/:city/watches: asks the service to watch the city.
pub fn watch(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  use city <- with_city(request)
  case forecast_service.watch_city(services.forecasts, city) {
    Ok(watch) -> json_response(status.created, watch_json(watch))
    Error(error) -> error_response(error)
  }
}

/// GET /forecasts/:city/hourly: the hourly forecast, streamed from the
/// service to the client chunk by chunk.
pub fn hourly(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  use city <- with_city(request)
  case forecast_service.stream_hourly(services.forecasts, city) {
    Ok(lines) -> stream_response(status.ok, lines, "text/plain")
    Error(error) -> error_response(error)
  }
}

/// The answer to each error of the forecast service.
fn error_response(error: ForecastError) -> Response {
  case error {
    UnknownCity(city:) ->
      json_response(status.not_found, error_json("No forecast for " <> city))
    NoAnswerInTime(timeout_ms:) ->
      json_response(
        gateway_timeout,
        error_json(
          "The forecast service did not answer in "
          <> int.to_string(timeout_ms)
          <> " ms",
        ),
      )
    ServiceFailed(reason:) ->
      json_response(
        bad_gateway,
        error_json("The forecast service failed: " <> reason),
      )
  }
}

fn with_city(request: Request, next: fn(String) -> Response) -> Response {
  case require_string(request, "city") {
    Ok(city) -> next(city)
    Error(problem) ->
      json_response(
        error.to_status_code(problem),
        error_json(error.message(problem)),
      )
  }
}

fn forecast_json(forecast: Forecast) -> String {
  json.object([
    #("city", json.string(forecast.city)),
    #("high", json.int(forecast.high)),
    #("low", json.int(forecast.low)),
  ])
  |> json.to_string
}

fn watch_json(watch: Watch) -> String {
  json.object([#("watch", json.string(watch.id))]) |> json.to_string
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))]) |> json.to_string
}
