//// Starts the links app: `gleam run -m links/main`. It reads its settings
//// from the environment and from `.env`, and stops at once when one is
//// missing or wrong.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import gleam/io
import links/configuration.{type Configuration}
import links/router as links_router
import links/services as links_services

pub fn main() {
  case configuration.load() {
    Ok(settings) -> start(settings)
    Error(error) -> stop(configuration.describe_error(error))
  }
}

fn start(settings: Configuration) {
  io.println("Starting with " <> configuration.describe(settings))
  let assert Ok(Nil) =
    dream.new()
    |> context(EmptyContext)
    |> services(links_services.from_configuration(settings))
    |> router(links_router.create_router())
    |> bind("localhost")
    |> listen(settings.port)
}

/// Prints the reason on standard error, and stops the program with exit
/// status 1, so that the deployment sees the failure.
fn stop(reason: String) -> a {
  io.println_error("The links app cannot start: " <> reason)
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a
