//// Design principles: explicit configuration
////
//// main shows the services, the routes, the bind address and the port.

import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub type Services {
  Services(database_url: String)
}

pub fn main() {
  server.new()
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.bind("localhost")
  |> server.listen(3000)
}

pub fn initialize_services() -> Services {
  Services(database_url: "postgres://localhost/app")
}

pub fn create_router() {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
}

fn show_home(_request: Request, _context, _services: Services) -> Response {
  text_response(ok, "Home")
}
