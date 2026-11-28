//// README: A Quick Example
////
//// The smallest useful Dream server, as shown in the root README.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_request, _context, _services) {
  text_response(ok, "Hello, world!")
}

pub fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.router(app_router())
    |> server.bind("localhost")
    |> server.listen(3000)
}
