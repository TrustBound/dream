//// Getting started guide: the app of examples/simplest/src/main.gleam
////
//// The same code as the example, so the test of the guide tests the code
//// that the guide runs.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server

/// The controller of GET / - returns "Hello, World!"
pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

/// The routes of the app. Public, so a test can send requests through them.
pub fn app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

/// Starts the server on localhost, port 3000
pub fn main() {
  server.new()
  |> server.router(app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
