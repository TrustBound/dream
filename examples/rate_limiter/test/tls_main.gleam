//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import clock.{SystemClock}
import dream/servers/mist/server.{bind, listen, router, services, tls} as dream
import gleam/io
import router.{create_router}
import services.{type Services, start_services}
import services/rate_limiter_service

pub fn main() -> Nil {
  case
    start_services(
      "rate_limit",
      rate_limiter_service.default_config(),
      SystemClock,
    )
  {
    Ok(app_services) -> start_server(app_services)
    Error(message) -> io.println_error("The app did not start: " <> message)
  }
}

fn start_server(app_services: Services) -> Nil {
  let assert Ok(Nil) =
    dream.new()
    |> services(app_services)
    |> router(create_router())
    |> bind("localhost")
    |> tls(
      certfile: "build/test_tls/cert.pem",
      keyfile: "build/test_tls/key.pem",
    )
    |> listen(3000)
  Nil
}
