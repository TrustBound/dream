//// admin_middleware.gleam
////
//// Authorization middleware that ensures the user has admin role.
//// Expects auth_middleware to have already validated token and populated context.

import context.{type AuthContext, User}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/option
import services.{type Services}

pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check user role from context (auth_middleware should have populated this)
  case context.user {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Not authenticated")
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
        status.forbidden,
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
