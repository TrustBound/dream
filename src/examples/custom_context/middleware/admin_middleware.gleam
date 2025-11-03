//// admin_middleware.gleam
////
//// Authorization middleware that ensures the user has admin role.
//// Also validates a hard-coded admin token for demonstration.

import dream/core/http/statuses.{forbidden_status, unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, text_response,
}
import examples/custom_context/context.{type AuthContext, User}
import examples/custom_context/services.{type Services, Services}
import gleam/option

pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  _services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check for hard-coded admin token
  case transaction.get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        unauthorized_status(),
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) -> check_admin_token(request, context, token, next)
  }
}

fn check_admin_token(
  request: Request,
  context: AuthContext,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case token {
    "Bearer admin-token" -> check_user_role(request, context, next)
    _ ->
      text_response(unauthorized_status(), "Unauthorized: Invalid admin token")
  }
}

fn check_user_role(
  request: Request,
  context: AuthContext,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case context.user {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) ->
      check_role(role, request, context, next)
  }
}

fn check_role(
  role: String,
  request: Request,
  context: AuthContext,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case role {
    "admin" -> next(request, context, Services)
    _ ->
      text_response(
        forbidden_status(),
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
