//// Task App - Main entry point
////
//// Demonstrates Dream's clean architecture with:
//// - HTMX for dynamic UI
//// - Semantic, classless HTML
//// - Composable matcha templates
//// - Clean separation of concerns

import config
import context
import dream/servers/mist/server
import gleam/int
import gleam/io
import router
import services

pub fn main() {
  io.println("Loading configuration...")
  let assert Ok(cfg) = config.load()

  io.println("Initializing services...")
  let svc = services.initialize(cfg)

  io.println(
    "Starting server on " <> cfg.host <> ":" <> int.to_string(cfg.port),
  )

  server.new()
  |> server.context(context.new())
  |> server.services(svc)
  |> server.router(router.create_router())
  |> server.bind(cfg.host)
  |> server.listen(cfg.port)
}
