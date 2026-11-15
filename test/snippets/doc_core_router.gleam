//// Examples for the doc comments of `dream/router`.

import dream/http/header.{Header}
import dream/http/request.{Get, Post, Put, get_param, get_string_param}
import dream/http/response.{type Response, Response, text_response}
import dream/http/status
import dream/router.{find_route, route, router, stream_route}
import gleam/option.{None, Some}

pub fn parameter_router() {
  router()
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:user_id/posts",
    controller: show_posts,
    middleware: [],
  )
}

pub fn admin_router() {
  router()
  |> route(
    method: Get,
    path: "/admin/users",
    controller: admin_users,
    middleware: [auth_middleware, logging_middleware],
  )
}

pub fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: home, middleware: [])
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
}

pub fn add_routes(router) {
  // Simple route
  let router =
    route(
      router,
      method: Get,
      path: "/",
      controller: home_controller,
      middleware: [],
    )

  // Route with path parameter
  let router =
    route(
      router,
      method: Get,
      path: "/users/:id",
      controller: show_user,
      middleware: [],
    )

  // Route with middleware
  let router =
    route(
      router,
      method: Post,
      path: "/admin/users",
      controller: create_user,
      middleware: [auth, logging],
    )

  // Wildcard route for static files
  route(
    router,
    method: Get,
    path: "/assets/**path",
    controller: serve_static,
    middleware: [],
  )
}

pub fn add_upload_routes(router) {
  router
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: handle_upload,
    middleware: [auth],
  )
  |> stream_route(
    method: Put,
    path: "/files/:id",
    controller: replace_file,
    middleware: [],
  )
}

pub fn find_user_params(router, request) {
  let app_router =
    router
    |> route(
      method: Get,
      path: "/users/:id",
      controller: show_user,
      middleware: [],
    )

  case find_route(app_router, request) {
    Some(#(_route, params)) -> {
      // route.controller is show_user
      // params is [#("id", "123")] if path was "/users/123"
      params
    }
    // No route matched
    None -> []
  }
}

// Controllers and middleware for the examples above

fn home(_request, _context, _services) {
  text_response(status.ok, "Home")
}

fn home_controller(_request, _context, _services) {
  text_response(status.ok, "Home")
}

fn show_user(request, _context, _services) {
  case get_string_param(request, "id") {
    Ok(id) -> text_response(status.ok, "User " <> id)
    Error(message) -> text_response(status.bad_request, message)
  }
}

fn show_posts(request, _context, _services) {
  case get_string_param(request, "user_id") {
    Ok(user_id) -> text_response(status.ok, "Posts by user " <> user_id)
    Error(message) -> text_response(status.bad_request, message)
  }
}

fn create_user(_request, _context, _services) {
  text_response(status.created, "Created")
}

fn admin_users(_request, _context, _services) {
  text_response(status.ok, "Admin users")
}

fn serve_static(request, _context, _services) {
  case get_param(request, "path") {
    Ok(param) -> text_response(status.ok, "Asset " <> param.raw)
    Error(message) -> text_response(status.bad_request, message)
  }
}

fn handle_upload(_request, _context, _services) {
  text_response(status.created, "Uploaded")
}

fn replace_file(_request, _context, _services) {
  text_response(status.ok, "Replaced")
}

fn auth_middleware(request, context, services, next) {
  let response = next(request, context, services)
  mark_response(response, "auth")
}

fn logging_middleware(request, context, services, next) {
  let response = next(request, context, services)
  mark_response(response, "logging")
}

fn auth(request, context, services, next) {
  next(request, context, services)
}

fn logging(request, context, services, next) {
  next(request, context, services)
}

// Each middleware adds a header on the way out, so the headers show the
// order in which the middleware ran.
fn mark_response(response: Response, middleware_name: String) -> Response {
  Response(..response, headers: [
    Header("X-Middleware", middleware_name),
    ..response.headers
  ])
}
