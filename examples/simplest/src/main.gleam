//// main.gleam
////
//// The simplest possible Dream application.
//// Everything in one file - inline controller, router, and server setup.

import dream/context
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, route, router}
import dream/servers/mist/server.{
  bind, context, listen, router as set_router, services,
}

/// Inline controller - returns "Hello, World!"
fn index(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

/// Main entry point - sets up and starts the server
pub fn main() {
  let app_router =
    router
    |> route(method: Get, path: "/", controller: index, middleware: [])

  server.new()
  |> context(context.AppContext(request_id: ""))
  |> services(router.EmptyServices)
  |> set_router(app_router)
  |> bind("localhost")
  |> listen(3000)
}
