//// The services of the app: what each controller needs from outside.

import dream_http_client/client.{type ClientRequest}
import forecast_service
import gleam/http

pub type Services {
  Services(forecasts: ClientRequest)
}

/// The services of the running app: the forecast service at its real
/// address. The app builds the base request one time, at start.
pub fn initialize_services() -> Services {
  Services(forecasts: forecast_service.base_request(
    http.Https,
    "forecasts.example.com",
    443,
  ))
}
