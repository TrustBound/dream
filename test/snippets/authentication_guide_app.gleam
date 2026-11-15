//// Authentication guide: middleware, routes and a controller
////
//// Shown in excerpts in docs/guides/authentication.md.

import dream/http.{
  type Request, type Response, created, get_header, json_response, ok,
  text_response, unauthorized,
}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import snippets/authentication_guide_context.{
  type AuthContext, type User, AuthContext,
}

pub type Services {
  Services(tokens: List(#(String, User)))
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(header) -> verify_token(request, context, services, header, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: Services,
  header: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(services, header) {
    Error(Nil) -> text_response(unauthorized, "Invalid token")
    Ok(user) -> {
      // Enrich context with authenticated user
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

// Replace with real validation logic (for example, JWT verification)
fn validate_token(services: Services, header: String) -> Result(User, Nil) {
  case header {
    "Bearer " <> token -> list.key_find(services.tokens, token)
    _ -> Error(Nil)
  }
}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  // Public route
  |> route(method: Get, path: "/", controller: public_index, middleware: [])
  // Protected routes
  |> route(method: Get, path: "/profile", controller: show_profile, middleware: [
    auth_middleware,
  ])
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}

pub fn show_profile(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> json_response(ok, user_to_json(user))
    None -> text_response(unauthorized, "Authentication required")
  }
}

fn public_index(
  _request: Request,
  _context: AuthContext,
  _services: Services,
) -> Response {
  text_response(ok, "Welcome")
}

fn create_post(
  request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) ->
      text_response(created, user.email <> " wrote: " <> request.body)
    None -> text_response(unauthorized, "Authentication required")
  }
}

fn user_to_json(user: User) -> String {
  json.object([
    #("id", json.string(user.id)),
    #("email", json.string(user.email)),
    #("role", json.string(user.role)),
  ])
  |> json.to_string
}
