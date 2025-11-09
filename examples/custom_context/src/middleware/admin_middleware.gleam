//// admin_middleware.gleam
////
//// Authorization middleware that ensures the user has admin role.
//// Expects auth_middleware to have already validated token and populated context.

import dream_helpers/statuses.{forbidden_status, unauthorized_status}
import dream/core/http/transaction.{type Request, type Response}
import dream_helpers/http.{text_response}
import context.{type AuthContext, User}
import services.{type Services}
import gleam/option

pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check user role from context (auth_middleware should have populated this)
  case context.user {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) ->
      check_role(role, request, context, services, next)
  }
}

fn check_role(
  role: String,
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case role {
    "admin" -> next(request, context, services)
    _ ->
      text_response(
        forbidden_status(),
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
