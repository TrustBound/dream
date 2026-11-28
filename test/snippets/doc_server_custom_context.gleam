//// Doc comment example: dream/servers/mist/server, module "Custom Context
//// and Services".

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import gleam/option.{None}

pub type MyContext {
  MyContext(request_id: String, user: option.Option(User), session: Session)
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.context(MyContext(
      request_id: "",
      user: None,
      session: empty_session(),
    ))
    |> server.services(initialize_services())
    |> server.router(create_router())
    |> server.listen(3000)
}

pub type User {
  User(name: String)
}

pub type Session {
  Session(values: List(#(String, String)))
}

pub type Services {
  Services(greeting: String)
}

pub fn empty_session() -> Session {
  Session(values: [])
}

pub fn initialize_services() -> Services {
  Services(greeting: "Hello")
}

pub fn create_router() -> Router(MyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, context: MyContext, services: Services) {
  text_response(ok, services.greeting <> ", " <> user_name(context.user))
}

fn user_name(user: option.Option(User)) -> String {
  case user {
    option.Some(User(name:)) -> name
    None -> "guest"
  }
}
