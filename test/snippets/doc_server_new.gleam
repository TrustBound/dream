//// Doc comment example: dream/servers/mist/server.new, simple example.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.router(my_router())
    |> server.listen(3000)
}

pub fn my_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Hello from Dream")
}
