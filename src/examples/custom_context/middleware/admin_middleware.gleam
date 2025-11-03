//// admin_middleware.gleam
////
//// Authorization middleware that ensures the user has admin role.
//// Also validates a hard-coded admin token for demonstration.

import dream/core/http/statuses.{forbidden_status, unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, get_header, text_response,
}
import examples/custom_context/context.{type AuthContext, User}
import gleam/option

pub fn admin_middleware(
  request: Request(AuthContext),
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  // Check for hard-coded admin token
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        unauthorized_status(),
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) -> check_admin_token(request, token, next)
  }
}

fn check_admin_token(
  request: Request(AuthContext),
  token: String,
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  case token {
    "Bearer admin-token" -> check_user_role(request, next)
    _ ->
      text_response(unauthorized_status(), "Unauthorized: Invalid admin token")
  }
}

fn check_user_role(
  request: Request(AuthContext),
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  case request.context.user {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) -> check_role(role, request, next)
  }
}

fn check_role(
  role: String,
  request: Request(AuthContext),
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  case role {
    "admin" -> next(request)
    _ ->
      text_response(
        forbidden_status(),
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
