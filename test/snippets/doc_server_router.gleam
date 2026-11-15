//// Doc comment example: dream/servers/mist/server.router

import dream/http.{ok, text_response}
import dream/http/request.{type Request, Get, get_string_param}
import dream/router.{type Router, route, router}
import dream/servers/mist/server

pub fn create_router() -> Router(MyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
}

pub fn main() {
  server.new()
  |> server.context(MyContext(request_id: ""))
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.listen(3000)
}

pub type MyContext {
  MyContext(request_id: String)
}

pub type Services {
  Services(greeting: String)
}

pub fn initialize_services() -> Services {
  Services(greeting: "Hello")
}

fn index(_request, _context: MyContext, services: Services) {
  text_response(ok, services.greeting)
}

fn show_user(request, _context: MyContext, _services: Services) {
  text_response(ok, "User " <> user_id(request))
}

fn user_id(request: Request) -> String {
  case get_string_param(request, "id") {
    Ok(id) -> id
    Error(_message) -> "unknown"
  }
}
