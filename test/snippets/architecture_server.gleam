//// Architecture reference: the server
////
//// Server builders for a simple app, for an app that uses AppContext, and
//// for an app with its own context and services.

import dream/context.{type AppContext, type EmptyContext, AppContext}
import dream/dream.{type Dream}
import dream/http.{type Request, type Response, ok, text_response}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server
import gleam/option.{type Option, None}
import mist.{type Builder, type Connection, type ResponseData}

pub type User {
  User(name: String)
}

pub type MyContext {
  MyContext(request_id: String, user: Option(User))
}

pub type Database {
  Database(users: List(User))
}

pub type Services {
  Services(database: Database)
}

pub fn initialize_services() -> Services {
  let database = Database(users: [User(name: "Ada")])
  Services(database: database)
}

fn show_home(
  _request: Request,
  _context: context,
  _services: services,
) -> Response {
  text_response(ok, "Home")
}

pub fn create_router() -> Router(context, services) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
}

pub fn create_simple_server() -> Dream(
  Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
  Router(EmptyContext, EmptyServices),
) {
  server.new()
  |> server.router(create_router())
  |> server.bind("localhost")
}

pub fn create_app_context_server() -> Dream(
  Builder(Connection, ResponseData),
  AppContext,
  EmptyServices,
  Router(AppContext, EmptyServices),
) {
  server.new()
  |> server.context(AppContext(request_id: ""))
  |> server.router(create_router())
}

pub fn create_custom_server() -> Dream(
  Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.bind("localhost")
}

pub fn main() {
  let assert Ok(Nil) =
    create_custom_server()
    |> server.listen(3000)
}
