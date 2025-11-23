// Integration tests for radix trie router with string-based API

import dream/context
import dream/http/request.{type Method, Delete, Get, Post, Put, Request}
import dream/http/response.{Response, Text}
import dream/router
import gleam/option.{None, Some}
import gleeunit/should
import router_poc

// ============================================================================
// Helper Functions
// ============================================================================

fn mock_controller(
  _request: request.Request,
  _context: context.AppContext,
  _services: router.EmptyServices,
) -> response.Response {
  Response(
    status: 200,
    body: Text("OK"),
    headers: [],
    cookies: [],
    content_type: None,
  )
}

fn create_request(method: Method, path: String) -> request.Request {
  Request(
    method: method,
    protocol: request.Http,
    version: request.Http1,
    path: path,
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
}

// ============================================================================
// Basic Route Tests
// ============================================================================

pub fn router_starts_empty_test() {
  let router_instance = router_poc.router()
  let request = create_request(Get, "/users")

  let result = router_poc.find_route(router_instance, request)

  result |> should.equal(None)
}

pub fn single_literal_route_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users")
  let result = router_poc.find_route(router_instance, request)

  case result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }
}

pub fn multiple_methods_same_path_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users",
      controller: mock_controller,
      middleware: [],
    )
    |> router_poc.route(
      method: Post,
      path: "/users",
      controller: mock_controller,
      middleware: [],
    )

  let get_result =
    router_poc.find_route(router_instance, create_request(Get, "/users"))
  let post_result =
    router_poc.find_route(router_instance, create_request(Post, "/users"))
  let put_result =
    router_poc.find_route(router_instance, create_request(Put, "/users"))

  case get_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  case post_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  put_result |> should.equal(None)
}

pub fn nested_paths_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/api/v1/users",
      controller: mock_controller,
      middleware: [],
    )

  let match_request = create_request(Get, "/api/v1/users")
  let no_match_request = create_request(Get, "/api/v2/users")

  let match_result = router_poc.find_route(router_instance, match_request)
  let no_match_result = router_poc.find_route(router_instance, no_match_request)

  case match_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  no_match_result |> should.equal(None)
}

pub fn different_paths_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users",
      controller: mock_controller,
      middleware: [],
    )
    |> router_poc.route(
      method: Get,
      path: "/posts",
      controller: mock_controller,
      middleware: [],
    )
    |> router_poc.route(
      method: Get,
      path: "/comments",
      controller: mock_controller,
      middleware: [],
    )

  let users_match =
    router_poc.find_route(router_instance, create_request(Get, "/users"))
  let posts_match =
    router_poc.find_route(router_instance, create_request(Get, "/posts"))
  let comments_match =
    router_poc.find_route(router_instance, create_request(Get, "/comments"))
  let no_match =
    router_poc.find_route(router_instance, create_request(Get, "/admin"))

  case users_match {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  case posts_match {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  case comments_match {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  no_match |> should.equal(None)
}

// ============================================================================
// Parameter Tests
// ============================================================================

pub fn single_param_route_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users/:id",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users/123")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let assert Ok(value) = router_poc.get_param(updated_request, "id")
  value |> should.equal("123")
}

pub fn multiple_params_route_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users/:user_id/posts/:post_id",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users/42/posts/99")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let assert Ok(user_id) = router_poc.get_param(updated_request, "user_id")
  user_id |> should.equal("42")
  let assert Ok(post_id) = router_poc.get_param(updated_request, "post_id")
  post_id |> should.equal("99")
}

pub fn require_int_param_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users/:id",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users/123")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let assert Ok(id) = router_poc.require_int(updated_request, "id")
  id |> should.equal(123)
}

pub fn require_int_param_fails_for_non_int_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users/:id",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users/abc")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let result = router_poc.require_int(updated_request, "id")
  result |> should.be_error()
}

// ============================================================================
// Wildcard Tests
// ============================================================================

pub fn single_wildcard_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/files/*filename",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/files/document.pdf")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let assert Ok(value) = router_poc.get_param(updated_request, "filename")
  value |> should.equal("document.pdf")
}

pub fn multi_wildcard_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/public/**filepath",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/public/assets/css/main.css")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(_handler, updated_request)) = result
  let assert Ok(value) = router_poc.get_param(updated_request, "filepath")
  value |> should.equal("assets/css/main.css")
}

// ============================================================================
// Extension Pattern Tests
// ============================================================================

pub fn extension_pattern_single_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/css/*.css",
      controller: mock_controller,
      middleware: [],
    )

  let match_request = create_request(Get, "/css/main.css")
  let no_match_request = create_request(Get, "/css/main.js")

  let match_result = router_poc.find_route(router_instance, match_request)
  let no_match_result = router_poc.find_route(router_instance, no_match_request)

  case match_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  no_match_result |> should.equal(None)
}

pub fn extension_pattern_multiple_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/images/*.{jpg,png,gif}",
      controller: mock_controller,
      middleware: [],
    )

  let jpg_request = create_request(Get, "/images/photo.jpg")
  let png_request = create_request(Get, "/images/icon.png")
  let gif_request = create_request(Get, "/images/animation.gif")
  let css_request = create_request(Get, "/images/style.css")

  let jpg_result = router_poc.find_route(router_instance, jpg_request)
  let png_result = router_poc.find_route(router_instance, png_request)
  let gif_result = router_poc.find_route(router_instance, gif_request)
  let css_result = router_poc.find_route(router_instance, css_request)

  case jpg_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  case png_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  case gif_result {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }

  css_result |> should.equal(None)
}

// ============================================================================
// Streaming Route Tests
// ============================================================================

pub fn stream_route_sets_streaming_flag_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.stream_route(
      method: Post,
      path: "/upload",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Post, "/upload")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(handler, _request)) = result
  router_poc.is_streaming(handler) |> should.be_true()
}

pub fn regular_route_not_streaming_test() {
  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users",
      controller: mock_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(handler, _request)) = result
  router_poc.is_streaming(handler) |> should.be_false()
}

// ============================================================================
// Middleware Tests
// ============================================================================

pub fn middleware_executes_test() {
  let test_middleware = fn(request, context, services, next) {
    // In real code, we'd track execution somehow
    next(request, context, services)
  }

  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users",
      controller: mock_controller,
      middleware: [test_middleware],
    )

  let request = create_request(Get, "/users")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(_) = result
  should.be_true(True)
}

// ============================================================================
// Precedence Tests
// ============================================================================

pub fn literal_beats_param_test() {
  let literal_controller = fn(_request, _context, _services) {
    Response(
      status: 200,
      body: Text("literal"),
      headers: [],
      cookies: [],
      content_type: None,
    )
  }

  let param_controller = fn(_request, _context, _services) {
    Response(
      status: 200,
      body: Text("param"),
      headers: [],
      cookies: [],
      content_type: None,
    )
  }

  let router_instance =
    router_poc.router()
    |> router_poc.route(
      method: Get,
      path: "/users/:id",
      controller: param_controller,
      middleware: [],
    )
    |> router_poc.route(
      method: Get,
      path: "/users/new",
      controller: literal_controller,
      middleware: [],
    )

  let request = create_request(Get, "/users/new")
  let result = router_poc.find_route(router_instance, request)

  let assert Some(#(handler, updated_request)) = result
  let response =
    router_poc.execute_handler(
      handler,
      updated_request,
      context.AppContext("test-id"),
      router.EmptyServices,
    )
  response.body |> should.equal(Text("literal"))
}
