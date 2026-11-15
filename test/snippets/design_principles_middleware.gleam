//// Design principles: per-route middleware
////
//// The admin route lists both of its middleware: one finds the user, the
//// other checks that the user is an admin.

import dream/http.{
  type Request, type Response, forbidden, ok, text_response, unauthorized,
}
import dream/http/header.{get_header}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result

pub type Role {
  Admin
  Member
}

pub type User {
  User(name: String, role: Role)
}

pub type Context {
  Context(request_id: String, user: Option(User))
}

pub type Services {
  Services(users_by_token: List(#(String, User)))
}

pub fn require_user(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case find_user(request, services) {
    Ok(user) -> next(request, Context(..context, user: Some(user)), services)
    Error(Nil) -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn require_admin(
  request: Request,
  context: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  case context.user {
    Some(User(role: Admin, ..)) -> next(request, context, services)
    _ -> text_response(forbidden, "Forbidden")
  }
}

fn find_user(request: Request, services: Services) -> Result(User, Nil) {
  use token <- result.try(
    get_header(request.headers, "Authorization") |> option.to_result(Nil),
  )
  list.key_find(services.users_by_token, token)
}

pub fn show_admin_page(
  _request: Request,
  _context: Context,
  _services: Services,
) -> Response {
  text_response(ok, "Admin area")
}

pub fn create_router() -> Router(Context, Services) {
  router()
  |> route(
    method: Get,
    path: "/admin",
    controller: show_admin_page,
    middleware: [require_user, require_admin],
  )
}
