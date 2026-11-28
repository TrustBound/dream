//// A rate limit for each client, counted in an ETS table.
////
//// Run it with `make run`, then send 11 requests:
////
////   for i in {1..11}; do curl -i http://localhost:3000/api; done

import clock.{SystemClock}
import dream/servers/mist/server.{bind, listen, router, services} as dream
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
    |> listen(3000)
  Nil
}
