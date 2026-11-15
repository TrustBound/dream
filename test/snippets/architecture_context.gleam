//// Architecture reference: middleware and context
////
//// A middleware that finds the user for a token, puts the user in a custom
//// context, and passes the new context to the controller.

import dream/http.{type Request, type Response, ok, text_response, unauthorized}
import dream/http/header.{get_header}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type User {
  User(name: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

pub type Services {
  Services(users_by_token: List(#(String, User)))
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case find_user(request, services) {
    Ok(user) -> {
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
    Error(Nil) -> text_response(unauthorized, "Unauthorized")
  }
}

fn find_user(request: Request, services: Services) -> Result(User, Nil) {
  use token <- result.try(
    get_header(request.headers, "Authorization") |> option.to_result(Nil),
  )
  list.key_find(services.users_by_token, token)
}

pub fn show_profile(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> text_response(ok, "Hello, " <> user.name)
    None -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  |> route(method: Get, path: "/profile", controller: show_profile, middleware: [
    auth_middleware,
  ])
}
