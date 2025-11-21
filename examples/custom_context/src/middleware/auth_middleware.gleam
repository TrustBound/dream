//// auth_middleware.gleam
////
//// Authentication middleware that validates tokens and populates user context.

import context.{type AuthContext, type User, AuthContext, User}
import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/option
import services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        status.unauthorized,
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) ->
      validate_and_authenticate(request, context, services, token, next)
  }
}

fn validate_and_authenticate(
  request: Request,
  context: AuthContext,
  services: Services,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(token) {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Invalid token")
    option.Some(user) -> {
      let updated_context =
        AuthContext(request_id: context.request_id, user: option.Some(user))
      next(request, updated_context, services)
    }
  }
}

fn validate_token(token: String) -> option.Option(User) {
  case token {
    "Bearer admin-token" ->
      option.Some(User(id: "1", email: "admin@example.com", role: "admin"))
    "Bearer user-token" ->
      option.Some(User(id: "2", email: "user@example.com", role: "user"))
    _ -> option.None
  }
}
