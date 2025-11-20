//// Custom context example - demonstrating authentication and authorization

import context as app_context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import gleam/io
import gleam/option
import router as app_router
import services as app_services

pub fn main() {
  // Initialize services
  let app_services = app_services.initialize_services()

  // Start the server
  dream.new()
  |> context(app_context.AuthContext(request_id: "", user: option.None))
  |> services(app_services)
  |> router(app_router.create_router())
  |> bind("localhost")
  |> listen(3001)

  io.println("Custom context example server listening on http://localhost:3001")
  io.println("Try:")
  io.println("  GET /                          - Public endpoint")
  io.println(
    "  GET /users/1/posts/2           - Requires auth (Bearer user-token)",
  )
  io.println(
    "  GET /admin                     - Requires admin (Bearer admin-token)",
  )
}
