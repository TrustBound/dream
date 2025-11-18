//// Task App - Main entry point
////
//// Demonstrates Dream's clean architecture with:
//// - HTMX for dynamic UI
//// - Semantic, classless HTML
//// - Composable matcha templates
//// - Clean separation of concerns

import context
import dream/servers/mist/server
import gleam/io
import router
import services

pub fn main() {
  io.println("Initializing services...")
  let svc = services.initialize()

  io.println("Starting server on http://localhost:3000")

  server.new()
  |> server.context(context.new())
  |> server.services(svc)
  |> server.router(router.create_router())
  |> server.bind("0.0.0.0")
  |> server.listen(3000)
}

