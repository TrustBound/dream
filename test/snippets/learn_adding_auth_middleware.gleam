//// Lesson 3: the auth middleware (src/middleware/auth_middleware.gleam)

import dream/http.{
  type Request, type Response, get_header, text_response, unauthorized,
}
import gleam/option.{type Option, None, Some}
import snippets/learn_adding_auth_context.{
  type AuthContext, type User, AuthContext, User,
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: services,
  next: fn(Request, AuthContext, services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(token) -> verify_token(request, context, services, token, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: services,
  token: String,
  next: fn(Request, AuthContext, services) -> Response,
) -> Response {
  case validate_token(token) {
    None -> text_response(unauthorized, "Invalid token")
    Some(user) -> {
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

fn validate_token(token: String) -> Option(User) {
  case token {
    "Bearer admin-token" ->
      Some(User(id: "1", email: "admin@example.com", role: "admin"))
    "Bearer user-token" ->
      Some(User(id: "2", email: "user@example.com", role: "user"))
    _ -> None
  }
}
