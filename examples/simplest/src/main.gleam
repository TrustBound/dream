//// main.gleam
////
//// The simplest possible Dream application.
//// Everything in one file - inline controller, router, and server setup.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, route, router as create_router}
import dream/servers/mist/server.{bind, listen, router}

/// Inline controller - returns "Hello, World!"
fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

/// Main entry point - sets up and starts the server
pub fn main() {
  let app_router =
    create_router()
    |> route(method: Get, path: "/", controller: index, middleware: [])

  server.new()
  |> router(app_router)
  |> bind("localhost")
  |> listen(3000)
}
