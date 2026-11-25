//// A shop with a read-through product cache in an ETS table.
////
//// Run it with `gleam run -m main`, then:
////
////   curl -i http://localhost:3000/products/lamp

import clock.{SystemClock}
import dream/servers/mist/server
import gleam/io
import gleam/time/duration
import router.{create_router}
import services.{type Services, Settings, start_services}

pub fn main() -> Nil {
  let settings =
    Settings(
      table_prefix: "shop",
      catalog_delay_milliseconds: 500,
      time_to_live: duration.seconds(60),
      clock: SystemClock,
    )
  case start_services(settings) {
    Ok(services) -> start_server(services)
    Error(message) -> io.println_error("The shop did not start: " <> message)
  }
}

fn start_server(services: Services) -> Nil {
  let assert Ok(Nil) =
    server.new()
    |> server.services(services)
    |> server.router(create_router())
    |> server.bind("localhost")
    |> server.listen(3000)
  Nil
}
