//// Concepts: a logging middleware, and middleware on routes

import dream/http.{type Request, type Response, forbidden, ok, text_response}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/time/duration.{type Duration}
import gleam/time/timestamp
import snippets/concepts_context.{type AuthContext, User, auth_middleware}

pub fn logging_middleware(request, context, services, next) {
  let start_time = timestamp.system_time()

  // Call next (could be another middleware or the controller action)
  let response = next(request, context, services)

  let duration = timestamp.difference(start_time, timestamp.system_time())
  log_request(request, response, duration)

  // Return (possibly modified) response
  response
}

pub fn create_router() -> Router(AuthContext, services) {
  router()
  // Public
  |> route(method: Get, path: "/", controller: home, middleware: [])
  |> route(method: Post, path: "/admin", controller: admin, middleware: [
    // Run first
    auth_middleware,
    // Run second
    admin_check_middleware,
    // Run third
    logging_middleware,
  ])
}

fn log_request(
  request: Request,
  response: Response,
  duration: Duration,
) -> Nil {
  io.println(
    http.method_to_string(request.method)
    <> " "
    <> request.path
    <> " "
    <> int.to_string(response.status)
    <> " in "
    <> int.to_string(duration.to_milliseconds(duration))
    <> " ms",
  )
}

fn admin_check_middleware(
  request: Request,
  context: AuthContext,
  services: services,
  next: fn(Request, AuthContext, services) -> Response,
) -> Response {
  case context.user {
    Some(User(role: "admin", ..)) -> next(request, context, services)
    _ -> text_response(forbidden, "Admins only")
  }
}

fn home(
  _request: Request,
  _context: AuthContext,
  _services: services,
) -> Response {
  text_response(ok, "Welcome")
}

fn admin(
  _request: Request,
  _context: AuthContext,
  _services: services,
) -> Response {
  text_response(ok, "Admin area")
}
