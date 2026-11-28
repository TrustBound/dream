//// Doc comment example: dream/servers/mist/server.listen

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server

pub fn main() {
  server.new()
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.listen(3000)
}

pub type Services {
  Services(greeting: String)
}

pub fn initialize_services() -> Services {
  Services(greeting: "Hello from Dream")
}

pub fn create_router() -> Router(context, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, services: Services) {
  text_response(ok, services.greeting)
}
