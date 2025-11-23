// Example usage of the radix trie-based router
//
// Demonstrates realistic route definitions with parameters, wildcards,
// middleware, and streaming routes

import dream/context
import dream/http/request.{Delete, Get, Post, Put, Request}
import dream/http/response.{Response, Text}
import dream/router
import gleam/int
import gleam/option.{None, Some}
import router_poc

// ============================================================================
// Example Application Router
// ============================================================================

pub fn create_app_router() -> router_poc.Router(
  context.AppContext,
  router.EmptyServices,
) {
  router_poc.router()
  // Home page
  |> router_poc.route(
    method: Get,
    path: "/",
    controller: home_controller,
    middleware: [],
  )
  // User routes with authentication
  |> router_poc.route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [
      auth_middleware,
    ],
  )
  |> router_poc.route(
    method: Post,
    path: "/users",
    controller: create_user,
    middleware: [
      auth_middleware,
      validate_middleware,
    ],
  )
  |> router_poc.route(
    method: Put,
    path: "/users/:id",
    controller: update_user,
    middleware: [auth_middleware, validate_middleware],
  )
  |> router_poc.route(
    method: Delete,
    path: "/users/:id",
    controller: delete_user,
    middleware: [auth_middleware],
  )
  // Nested resource routes
  |> router_poc.route(
    method: Get,
    path: "/users/:user_id/posts/:post_id",
    controller: show_user_post,
    middleware: [logging_middleware],
  )
  // Static file serving with wildcards
  |> router_poc.route(
    method: Get,
    path: "/public/**filepath",
    controller: serve_static,
    middleware: [],
  )
  // Single wildcard for specific file access
  |> router_poc.route(
    method: Get,
    path: "/files/*filename",
    controller: serve_file,
    middleware: [],
  )
  // Extension pattern matching
  |> router_poc.route(
    method: Get,
    path: "/css/*.css",
    controller: serve_css,
    middleware: [],
  )
  |> router_poc.route(
    method: Get,
    path: "/images/*.{jpg,png,gif,svg}",
    controller: serve_image,
    middleware: [],
  )
  // Streaming upload route
  |> router_poc.stream_route(
    method: Post,
    path: "/upload/:id",
    controller: handle_upload,
    middleware: [auth_middleware],
  )
  // API versioning
  |> router_poc.route(
    method: Get,
    path: "/api/:version/users",
    controller: api_list_users,
    middleware: [api_middleware],
  )
}

// ============================================================================
// Controllers
// ============================================================================

fn home_controller(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  Response(
    status: 200,
    body: Text("<h1>Welcome to the Example App</h1>"),
    headers: [],
    cookies: [],
    content_type: None,
  )
}

fn show_user(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.require_int(request, "id") {
    Ok(id) ->
      Response(
        status: 200,
        body: Text("User " <> int.to_string(id)),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(err) ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn create_user(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  Response(
    status: 201,
    body: Text("User created"),
    headers: [],
    cookies: [],
    content_type: None,
  )
}

fn update_user(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.require_int(request, "id") {
    Ok(id) ->
      Response(
        status: 200,
        body: Text("User " <> int.to_string(id) <> " updated"),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(err) ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn delete_user(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.require_int(request, "id") {
    Ok(id) ->
      Response(
        status: 204,
        body: Text("User " <> int.to_string(id) <> " deleted"),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(err) ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn show_user_post(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  let user_id_result = router_poc.require_int(request, "user_id")
  let post_id_result = router_poc.require_int(request, "post_id")

  case user_id_result, post_id_result {
    Ok(user_id), Ok(post_id) ->
      Response(
        status: 200,
        body: Text(
          "User "
          <> int.to_string(user_id)
          <> ", Post "
          <> int.to_string(post_id),
        ),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(err), _ ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
    _, Error(err) ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn serve_static(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.get_param(request, "filepath") {
    Ok(filepath) ->
      Response(
        status: 200,
        body: Text("Serving: " <> filepath),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(_) ->
      Response(
        status: 404,
        body: Text("Not found"),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn serve_file(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.get_param(request, "filename") {
    Ok(filename) ->
      Response(
        status: 200,
        body: Text("File: " <> filename),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(_) ->
      Response(
        status: 404,
        body: Text("Not found"),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn serve_css(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  Response(
    status: 200,
    body: Text("body { margin: 0; }"),
    headers: [],
    cookies: [],
    content_type: None,
  )
}

fn serve_image(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  Response(
    status: 200,
    body: Text("<binary image data>"),
    headers: [],
    cookies: [],
    content_type: None,
  )
}

fn handle_upload(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.require_int(request, "id") {
    Ok(id) ->
      Response(
        status: 200,
        body: Text("Upload " <> int.to_string(id) <> " received"),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(err) ->
      Response(
        status: 400,
        body: Text(err),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

fn api_list_users(
  request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  case router_poc.get_param(request, "version") {
    Ok(version) ->
      Response(
        status: 200,
        body: Text("API " <> version <> " users list"),
        headers: [],
        cookies: [],
        content_type: None,
      )
    Error(_) ->
      Response(
        status: 400,
        body: Text("Invalid version"),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}

// ============================================================================
// Middleware
// ============================================================================

fn auth_middleware(
  request: request.Request,
  context: context.AppContext,
  services: router.EmptyServices,
  next: fn(request.Request, context.AppContext, router.EmptyServices) ->
    response.Response,
) -> response.Response {
  // In real app: check authentication token
  // For example, return 401 if not authenticated
  next(request, context, services)
}

fn validate_middleware(
  request: request.Request,
  context: context.AppContext,
  services: router.EmptyServices,
  next: fn(request.Request, context.AppContext, router.EmptyServices) ->
    response.Response,
) -> response.Response {
  // In real app: validate request body
  // For example, return 400 if invalid
  next(request, context, services)
}

fn logging_middleware(
  request: request.Request,
  context: context.AppContext,
  services: router.EmptyServices,
  next: fn(request.Request, context.AppContext, router.EmptyServices) ->
    response.Response,
) -> response.Response {
  // In real app: log the request
  // For example: log(request.path, request.method)
  next(request, context, services)
}

fn api_middleware(
  request: request.Request,
  context: context.AppContext,
  services: router.EmptyServices,
  next: fn(request.Request, context.AppContext, router.EmptyServices) ->
    response.Response,
) -> response.Response {
  // In real app: set API-specific headers, rate limiting, etc.
  next(request, context, services)
}

// ============================================================================
// Example Usage
// ============================================================================

pub fn example_request_flow() {
  let app_router = create_app_router()

  // Example: GET /users/123
  let req =
    Request(
      method: Get,
      protocol: request.Http,
      version: request.Http1,
      path: "/users/123",
      query: "",
      params: [],
      host: None,
      port: None,
      remote_address: None,
      body: "",
      stream: None,
      headers: [],
      cookies: [],
      content_type: None,
      content_length: None,
    )

  case router_poc.find_route(app_router, req) {
    Some(#(handler, updated_request)) -> {
      // Execute the handler with middleware
      let response =
        router_poc.execute_handler(
          handler,
          updated_request,
          context.AppContext("test-id"),
          router.EmptyServices,
        )

      // Response will be: Response(status: 200, body: "User 123")
      response
    }
    None ->
      Response(
        status: 404,
        body: Text("Not Found"),
        headers: [],
        cookies: [],
        content_type: None,
      )
  }
}
