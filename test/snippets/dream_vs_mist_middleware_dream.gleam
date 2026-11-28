//// Dream vs raw Mist: authentication with Dream
////
//// The auth middleware runs only on the route that lists it, and it passes
//// the user to the controller in the context.

import dream/http.{
  type Request, type Response, created, ok, text_response, unauthorized,
}
import dream/http/header.{get_header}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type User {
  User(name: String)
}

pub type Context {
  Context(request_id: String, user: Option(User))
}

pub type Services {
  Services(users_by_token: List(#(String, User)))
}

pub fn auth_middleware(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case authenticate(request, services) {
    Ok(user) -> {
      let enriched_context = Context(..context, user: Some(user))
      next(request, enriched_context, services)
    }
    Error(Nil) -> text_response(unauthorized, "Unauthorized")
  }
}

fn authenticate(request: Request, services: Services) -> Result(User, Nil) {
  use token <- result.try(
    get_header(request.headers, "Authorization") |> option.to_result(Nil),
  )
  list.key_find(services.users_by_token, token)
}

pub fn show_home(
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  text_response(ok, "Welcome")
}

pub fn create_post(
  _request: Request,
  context: Context,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> text_response(created, "Post created by " <> user.name)
    None -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn create_router() -> Router(Context, Services) {
  router()
  // Public
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  // Protected
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}

pub fn initialize_services() -> Services {
  Services(users_by_token: [#("Bearer secret-token", User(name: "Ada"))])
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.context(Context(request_id: "", user: None))
    |> server.services(initialize_services())
    |> server.router(create_router())
    |> server.listen(3000)
}
