//// Quickstart
////
//// The server file that the quickstart builds and explains.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Hello, World!")
}

pub fn create_app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn main() {
  server.new()
  |> server.router(create_app_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}
