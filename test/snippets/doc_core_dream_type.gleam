//// Example for the doc comment of the `dream/dream.Dream` type.

import dream/dream.{type Dream}
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import gleam/option.{type Option, None}
import mist.{type Connection, type ResponseData}

// Your application types
pub type MyContext {
  MyContext(request_id: String, user: Option(User))
}

pub type Services {
  Services(database_url: String, cache_size: Int)
}

// Dream server with your types
pub fn create_server() -> Dream(
  mist.Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(Services(
    database_url: "postgres://localhost/app",
    cache_size: 100,
  ))
  |> server.router(my_router())
}

pub type User {
  User(name: String)
}

fn home(_request, _context, _services) {
  text_response(status.ok, "Home")
}

pub fn my_router() -> Router(MyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: home, middleware: [])
}
