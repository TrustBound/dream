//// Design principles: the builder pattern
////
//// Each step takes the server configuration and returns a new one. The last
//// step starts the server.

import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn show_home(_request: Request, _context, _services) -> Response {
  text_response(ok, "Home")
}

pub fn configure_server() {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: show_home, middleware: []),
  )
  |> server.bind("localhost")
  |> server.max_body_size(1_000_000)
}

pub fn main() {
  let assert Ok(Nil) =
    configure_server()
    |> server.listen(3000)
}
