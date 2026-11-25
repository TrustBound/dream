//// Doc comment example: dream/servers/mist/server.context

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import gleam/option.{type Option, None}

pub type MyContext {
  MyContext(request_id: String, user: Option(User))
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.context(MyContext(request_id: "", user: None))
    |> server.services(my_services())
    |> server.router(my_router())
    |> server.listen(3000)
}

pub type User {
  User(name: String)
}

pub type Services {
  Services(greeting: String)
}

pub fn my_services() -> Services {
  Services(greeting: "Hello")
}

pub fn my_router() -> Router(MyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, context: MyContext, services: Services) {
  text_response(ok, services.greeting <> ", " <> user_name(context.user))
}

fn user_name(user: Option(User)) -> String {
  case user {
    option.Some(User(name:)) -> name
    None -> "guest"
  }
}
