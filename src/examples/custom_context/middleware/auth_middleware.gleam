//// auth_middleware.gleam
////
//// Authentication middleware that validates tokens and populates user context.

import dream/core/http/statuses.{unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, text_response,
}
import examples/custom_context/context.{
  type AuthContext, type User, AuthContext, User,
}
import examples/custom_context/services.{type Services, Services}
import gleam/option

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  _services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case transaction.get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        unauthorized_status(),
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) -> validate_and_authenticate(request, context, token, next)
  }
}

fn validate_and_authenticate(
  request: Request,
  context: AuthContext,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(token) {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Invalid token")
    option.Some(user) -> {
      let updated_context =
        AuthContext(
          request_id: context.request_id,
          user: option.Some(user),
        )
      next(request, updated_context, Services)
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
