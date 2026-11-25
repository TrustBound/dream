//// Doc comment example: dream/servers/mist/server, module "Quick Start".

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.router(create_router())
    |> server.listen(3000)
}

pub fn create_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Hello from Dream")
}
