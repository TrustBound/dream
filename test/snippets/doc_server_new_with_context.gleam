//// Doc comment example: dream/servers/mist/server.new, with context and
//// services.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import gleam/option.{None}

pub fn main() {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(my_services())
  |> server.router(my_router())
  |> server.listen(3000)
}

pub type MyContext {
  MyContext(request_id: String, user: option.Option(String))
}

pub type Services {
  Services(greeting: String)
}

pub fn my_services() -> Services {
  Services(greeting: "Hello from Dream")
}

pub fn my_router() -> Router(MyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context: MyContext, services: Services) {
  text_response(ok, services.greeting)
}
