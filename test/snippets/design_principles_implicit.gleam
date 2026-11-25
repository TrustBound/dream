//// Design principles: implicit configuration (what not to do)
////
//// main calls a start helper. The port, the bind address, the services and
//// the routes are all decided inside start, out of sight of main.

import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

pub type Services {
  Services(database_url: String)
}

pub fn main() {
  start()
}

pub fn start() {
  let assert Ok(Nil) =
    configure_server()
    |> server.listen(8080)
}

pub fn configure_server() {
  server.new()
  |> server.services(Services(database_url: "postgres://localhost/app"))
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: show_home, middleware: []),
  )
  |> server.bind("0.0.0.0")
}

fn show_home(_request: Request, _context, _services: Services) -> Response {
  text_response(ok, "Home")
}
