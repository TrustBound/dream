//// Architecture reference: the router
////
//// Two typed controllers, a middleware, and a router built with the builder
//// pattern.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, created, ok, text_response, unauthorized,
}
import dream/http/header.{get_header}
import dream/http/request.{Get, Post}
import dream/router.{type EmptyServices, type Router, route, router}
import gleam/option.{None, Some}

pub fn show_home(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok, "Home")
}

pub fn create_user(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(created, "User created")
}

pub fn require_token(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
  next: fn(Request, EmptyContext, EmptyServices) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    Some(_token) -> next(request, context, services)
    None -> text_response(unauthorized, "Unauthorized")
  }
}

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: show_home, middleware: [])
  |> route(method: Post, path: "/users", controller: create_user, middleware: [
    require_token,
  ])
}
