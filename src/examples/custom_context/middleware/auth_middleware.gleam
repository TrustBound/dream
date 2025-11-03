//// auth_middleware.gleam
////
//// Authentication middleware that validates tokens and populates user context.

import dream/core/http/statuses.{unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, get_header, set_context, text_response,
}
import examples/custom_context/context.{
  type AuthContext, type User, AuthContext, User,
}
import gleam/option

pub fn auth_middleware(
  request: Request(AuthContext),
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        unauthorized_status(),
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) -> validate_and_authenticate(request, token, next)
  }
}

fn validate_and_authenticate(
  request: Request(AuthContext),
  token: String,
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  case validate_token(token) {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Invalid token")
    option.Some(user) -> {
      let updated_context =
        AuthContext(
          request_id: request.context.request_id,
          user: option.Some(user),
        )
      let request_with_user = set_context(request, updated_context)
      next(request_with_user)
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
