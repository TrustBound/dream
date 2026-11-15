//// Streaming quick reference: Server Configuration
////
//// A server with a larger body limit for buffered routes, as shown in
//// docs/guides/streaming-quick-reference.md.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, type Router, route}
import dream/servers/mist/server.{bind, listen, max_body_size}

pub fn main() {
  create_server()
  |> listen(3000)
}

pub fn create_server() {
  server.new()
  |> server.router(create_router())
  // 100MB for buffered routes (default is 10MB)
  |> max_body_size(100_000_000)
  |> bind("localhost")
}

fn create_router() -> Router(EmptyContext, EmptyServices) {
  router.router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello")
}
