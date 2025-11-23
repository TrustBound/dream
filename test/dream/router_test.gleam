import dream/context
import dream/http/header.{Header}
import dream/http/request.{
  type Method, type Request, Get, Http, Http1, Patch, Post, Put, Request,
}
import dream/http/response.{type Response, Response, Text}
import dream/router.{
  type EmptyServices, build_controller_chain, find_route, route, router,
  stream_route,
}
import gleam/option
import gleeunit/should

// ============================================================================
// Helper Functions
// ============================================================================

fn create_test_request(method_value: Method, path_value: String) -> Request {
  Request(
    method: method_value,
    protocol: Http,
    version: Http1,
    path: path_value,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn test_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("test"),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

fn literal_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("literal"),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

fn param_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("param"),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

// ============================================================================
// Streaming Flag Tests
// ============================================================================

pub fn stream_route_sets_streaming_flag_to_true_test() {
  let test_router =
    router()
    |> stream_route(
      method: Post,
      path: "/upload",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Post, "/upload")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.streaming |> should.be_true()
    }
    option.None -> should.fail()
  }
}

pub fn stream_route_with_put_sets_streaming_flag_to_true_test() {
  let test_router =
    router()
    |> stream_route(
      method: Put,
      path: "/upload",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Put, "/upload")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.streaming |> should.be_true()
    }
    option.None -> should.fail()
  }
}

pub fn stream_route_with_patch_sets_streaming_flag_to_true_test() {
  let test_router =
    router()
    |> stream_route(
      method: Patch,
      path: "/upload",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Patch, "/upload")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.streaming |> should.be_true()
    }
    option.None -> should.fail()
  }
}

pub fn route_without_stream_sets_streaming_flag_to_false_test() {
  let test_router =
    router()
    |> route(
      method: Post,
      path: "/upload",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Post, "/upload")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.streaming |> should.be_false()
    }
    option.None -> should.fail()
  }
}

// ============================================================================
// Basic Route Tests
// ============================================================================

pub fn router_starts_empty_test() {
  let request = create_test_request(Get, "/users")
  let result = find_route(router(), request)
  result |> should.equal(option.None)
}

pub fn single_literal_route_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/users")
  let result = find_route(test_router, request)

  case result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }
}

pub fn multiple_methods_same_path_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )
    |> route(
      method: Post,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )

  let get_result = find_route(test_router, create_test_request(Get, "/users"))
  let post_result = find_route(test_router, create_test_request(Post, "/users"))
  let put_result = find_route(test_router, create_test_request(Put, "/users"))

  case get_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  case post_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  put_result |> should.equal(option.None)
}

pub fn nested_paths_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/api/v1/users",
      controller: test_handler,
      middleware: [],
    )

  let match_request = create_test_request(Get, "/api/v1/users")
  let no_match_request = create_test_request(Get, "/api/v2/users")

  let match_result = find_route(test_router, match_request)
  let no_match_result = find_route(test_router, no_match_request)

  case match_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  no_match_result |> should.equal(option.None)
}

pub fn different_paths_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/posts",
      controller: test_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/comments",
      controller: test_handler,
      middleware: [],
    )

  let users_match = find_route(test_router, create_test_request(Get, "/users"))
  let posts_match = find_route(test_router, create_test_request(Get, "/posts"))
  let comments_match =
    find_route(test_router, create_test_request(Get, "/comments"))
  let no_match = find_route(test_router, create_test_request(Get, "/admin"))

  case users_match {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  case posts_match {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  case comments_match {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  no_match |> should.equal(option.None)
}

// ============================================================================
// Parameter Tests
// ============================================================================

pub fn single_param_route_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/users/123")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("id", "123")])
    }
    option.None -> should.fail()
  }
}

pub fn multiple_params_route_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:user_id/posts/:post_id",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/users/42/posts/99")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(_route, params)) -> {
      // Parameters are accumulated in reverse order
      params
      |> should.equal([#("post_id", "99"), #("user_id", "42")])
    }
    option.None -> should.fail()
  }
}

// ============================================================================
// Wildcard Tests
// ============================================================================

pub fn single_wildcard_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/files/*filename",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/files/document.pdf")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("filename", "document.pdf")])
    }
    option.None -> should.fail()
  }
}

pub fn multi_wildcard_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/public/**filepath",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/public/assets/css/main.css")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("filepath", "assets/css/main.css")])
    }
    option.None -> should.fail()
  }
}

pub fn multi_wildcard_single_segment_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/public/**filepath",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/public/file.txt")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("filepath", "file.txt")])
    }
    option.None -> should.fail()
  }
}

// ============================================================================
// Extension Pattern Tests
// ============================================================================

pub fn extension_pattern_single_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/css/*.css",
      controller: test_handler,
      middleware: [],
    )

  let match_request = create_test_request(Get, "/css/main.css")
  let no_match_request = create_test_request(Get, "/css/main.js")

  let match_result = find_route(test_router, match_request)
  let no_match_result = find_route(test_router, no_match_request)

  case match_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  no_match_result |> should.equal(option.None)
}

pub fn extension_pattern_multiple_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/images/*.{jpg,png,gif}",
      controller: test_handler,
      middleware: [],
    )

  let jpg_request = create_test_request(Get, "/images/photo.jpg")
  let png_request = create_test_request(Get, "/images/icon.png")
  let gif_request = create_test_request(Get, "/images/animation.gif")
  let css_request = create_test_request(Get, "/images/style.css")

  let jpg_result = find_route(test_router, jpg_request)
  let png_result = find_route(test_router, png_request)
  let gif_result = find_route(test_router, gif_request)
  let css_result = find_route(test_router, css_request)

  case jpg_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  case png_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  case gif_result {
    option.Some(_) -> should.be_true(True)
    option.None -> should.fail()
  }

  css_result |> should.equal(option.None)
}

// ============================================================================
// Precedence Tests (Radix Trie Advantage)
// ============================================================================

pub fn literal_beats_param_test() {
  // With radix trie, literal always wins regardless of definition order
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/users/new",
      controller: literal_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/users/new")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.controller |> should.equal(literal_handler)
    }
    option.None -> should.fail()
  }
}

pub fn literal_beats_param_reverse_order_test() {
  // Should work the same even if literal is defined first
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/new",
      controller: literal_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/users/:id",
      controller: param_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/users/new")
  let result = find_route(test_router, request)

  case result {
    option.Some(#(route, _params)) -> {
      route.controller |> should.equal(literal_handler)
    }
    option.None -> should.fail()
  }
}

// ============================================================================
// Method Matching Tests
// ============================================================================

pub fn find_route_with_method_mismatch_returns_none_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Post, "/users")
  let result = find_route(test_router, request)

  result |> should.equal(option.None)
}

pub fn find_route_with_no_matching_route_returns_none_test() {
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users",
      controller: test_handler,
      middleware: [],
    )

  let request = create_test_request(Get, "/posts")
  let result = find_route(test_router, request)

  result |> should.equal(option.None)
}

// ============================================================================
// Middleware Chain Tests
// ============================================================================

pub fn build_controller_chain_with_no_middleware_returns_controller_test() {
  let controller = build_controller_chain([], test_handler)

  let request = create_test_request(Get, "/")
  let response =
    controller(request, context.AppContext("test"), router.EmptyServices)

  response.status |> should.equal(200)
}

pub fn build_controller_chain_with_middleware_wraps_controller_test() {
  let add_header_middleware = fn(req, ctx, services, next) {
    let response = next(req, ctx, services)
    Response(..response, headers: [
      Header("X-Custom", "value"),
      ..response.headers
    ])
  }

  let controller =
    build_controller_chain(
      [router.Middleware(add_header_middleware)],
      test_handler,
    )

  let request = create_test_request(Get, "/")
  let response =
    controller(request, context.AppContext("test"), router.EmptyServices)

  response.headers
  |> should.equal([
    Header("X-Custom", "value"),
    Header("Content-Type", "text/plain; charset=utf-8"),
  ])
}

pub fn build_controller_chain_with_multiple_middleware_executes_in_order_test() {
  let first_middleware = fn(req, ctx, services, next) {
    let response = next(req, ctx, services)
    Response(..response, headers: [Header("X-First", "1"), ..response.headers])
  }

  let second_middleware = fn(req, ctx, services, next) {
    let response = next(req, ctx, services)
    Response(..response, headers: [Header("X-Second", "2"), ..response.headers])
  }

  let controller =
    build_controller_chain(
      [
        router.Middleware(first_middleware),
        router.Middleware(second_middleware),
      ],
      test_handler,
    )

  let request = create_test_request(Get, "/")
  let response =
    controller(request, context.AppContext("test"), router.EmptyServices)

  // First middleware wraps second, so it runs last on the way out
  response.headers
  |> should.equal([
    Header("X-First", "1"),
    Header("X-Second", "2"),
    Header("Content-Type", "text/plain; charset=utf-8"),
  ])
}

// ============================================================================
// Regression Tests
// ============================================================================

pub fn param_name_remapping_when_routes_share_param_position_test() {
  // Test that routes with different param names at the same position
  // correctly remap params to match each route's declared param names.
  //
  // Scenario:
  // 1. Insert /users/:id first
  // 2. Insert /users/:user_id/posts second
  // 3. Both routes share the same param child node at /users/
  // 4. The trie node uses the first inserted param name ("id")
  // 5. But each route should extract params using its own declared name
  //
  // With Option 2 (param remapping):
  // - /users/123 should extract id=123 (route's declared param name)
  // - /users/123/posts should extract user_id=123 (route's declared param name)

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/users/:user_id/posts",
      controller: test_handler,
      middleware: [],
    )

  // Test that /users/123 extracts "id" (route's declared param name)
  let user_request = create_test_request(Get, "/users/123")
  let user_result = find_route(test_router, user_request)

  case user_result {
    option.Some(#(_route, params)) -> {
      // Should extract "id" (route's declared param name, not trie node's name)
      // Params are in reverse order for backward compatibility
      params |> should.equal([#("id", "123")])
    }
    option.None -> should.fail()
  }

  // Test that /users/123/posts extracts "user_id" (route's declared param name)
  let posts_request = create_test_request(Get, "/users/123/posts")
  let posts_result = find_route(test_router, posts_request)

  case posts_result {
    option.Some(#(_route, params)) -> {
      // Should extract "user_id" (route's declared param name, not trie node's name)
      // Params are in reverse order for backward compatibility
      params |> should.equal([#("user_id", "123")])
    }
    option.None -> should.fail()
  }
}

pub fn param_name_remapping_with_multiple_params_test() {
  // Test param remapping with routes that have multiple params
  // and share some param positions but not others.

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id/posts/:post_id",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/users/:user_id/comments/:comment_id",
      controller: test_handler,
      middleware: [],
    )

  // Test first route: should extract id and post_id (in reverse order for backward compatibility)
  let posts_request = create_test_request(Get, "/users/123/posts/456")
  let posts_result = find_route(test_router, posts_request)

  case posts_result {
    option.Some(#(_route, params)) -> {
      // Params are in reverse order (last param first) for backward compatibility
      params |> should.equal([#("post_id", "456"), #("id", "123")])
    }
    option.None -> should.fail()
  }

  // Test second route: should extract user_id and comment_id (in reverse order)
  let comments_request = create_test_request(Get, "/users/123/comments/789")
  let comments_result = find_route(test_router, comments_request)

  case comments_result {
    option.Some(#(_route, params)) -> {
      // Params are in reverse order (last param first) for backward compatibility
      params |> should.equal([#("comment_id", "789"), #("user_id", "123")])
    }
    option.None -> should.fail()
  }
}

pub fn param_name_remapping_with_wildcards_test() {
  // Test param remapping with wildcard segments

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/files/*file",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/images/*image",
      controller: test_handler,
      middleware: [],
    )

  // Test first route: should extract "file"
  let file_request = create_test_request(Get, "/files/document.pdf")
  let file_result = find_route(test_router, file_request)

  case file_result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("file", "document.pdf")])
    }
    option.None -> should.fail()
  }

  // Test second route: should extract "image"
  let image_request = create_test_request(Get, "/images/photo.jpg")
  let image_result = find_route(test_router, image_request)

  case image_result {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("image", "photo.jpg")])
    }
    option.None -> should.fail()
  }
}

pub fn extension_stripping_for_literal_routes_test() {
  // Test that routes without extensions match paths with extensions
  // This enables format detection in controllers (e.g., /products.json -> /products)

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/products",
      controller: test_handler,
      middleware: [],
    )

  // Test that /products.json matches /products route
  let json_request = create_test_request(Get, "/products.json")
  let json_result = find_route(test_router, json_request)

  case json_result {
    option.Some(#(route, params)) -> {
      // Route should match
      // Path should be preserved with extension for controller to detect format
      route.path |> should.equal("/products.json")
      params |> should.equal([])
    }
    option.None -> should.fail()
  }

  // Test that /products.csv also matches /products route
  let csv_request = create_test_request(Get, "/products.csv")
  let csv_result = find_route(test_router, csv_request)

  case csv_result {
    option.Some(#(route, params)) -> {
      route.path |> should.equal("/products.csv")
      params |> should.equal([])
    }
    option.None -> should.fail()
  }

  // Test that /products (no extension) still works
  let plain_request = create_test_request(Get, "/products")
  let plain_result = find_route(test_router, plain_request)

  case plain_result {
    option.Some(#(route, params)) -> {
      route.path |> should.equal("/products")
      params |> should.equal([])
    }
    option.None -> should.fail()
  }
}

pub fn extension_stripping_for_param_routes_test() {
  // Test that routes with parameters match paths with extensions
  // e.g., /products/1.json should match /products/:id
  // IMPORTANT: Params must preserve the full value with extension for format detection

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/products/:id",
      controller: param_handler,
      middleware: [],
    )

  // Test that /products/1.json matches /products/:id
  let json_request = create_test_request(Get, "/products/1.json")
  let json_result = find_route(test_router, json_request)

  case json_result {
    option.Some(#(route, params)) -> {
      // Route should match
      // Path should be preserved with extension
      route.path |> should.equal("/products/1.json")
      // Param must preserve full value with extension for format detection
      // parse_path_param("1.json") will extract value="1" and format=Some("json")
      params |> should.equal([#("id", "1.json")])
    }
    option.None -> should.fail()
  }

  // Test that /products/123.csv matches /products/:id
  let csv_request = create_test_request(Get, "/products/123.csv")
  let csv_result = find_route(test_router, csv_request)

  case csv_result {
    option.Some(#(route, params)) -> {
      route.path |> should.equal("/products/123.csv")
      // Param must preserve full value with extension
      params |> should.equal([#("id", "123.csv")])
    }
    option.None -> should.fail()
  }

  // Test that /products/456 (no extension) still works
  let plain_request = create_test_request(Get, "/products/456")
  let plain_result = find_route(test_router, plain_request)

  case plain_result {
    option.Some(#(route, params)) -> {
      route.path |> should.equal("/products/456")
      params |> should.equal([#("id", "456")])
    }
    option.None -> should.fail()
  }
}

pub fn extension_stripping_edge_cases_test() {
  // Comprehensive edge case tests for extension stripping

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/files/*filename",
      controller: test_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/users/:id",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/posts/:post_id/comments",
      controller: param_handler,
      middleware: [],
    )

  // Edge case 1: Wildcards should capture full segments including extensions
  let wildcard_request = create_test_request(Get, "/files/document.pdf")
  let wildcard_result = find_route(test_router, wildcard_request)
  case wildcard_result {
    option.Some(#(_route, params)) -> {
      // Wildcards capture full segment, no extension stripping
      params |> should.equal([#("filename", "document.pdf")])
    }
    option.None -> should.fail()
  }

  // Edge case 2: Multiple dots in segment (e.g., "file.backup.tar.gz")
  let multi_dot_request = create_test_request(Get, "/files/file.backup.tar.gz")
  let multi_dot_result = find_route(test_router, multi_dot_request)
  case multi_dot_result {
    option.Some(#(_route, params)) -> {
      // Should capture full segment, extension stripping only splits on first dot
      // But for wildcards, we capture everything
      params |> should.equal([#("filename", "file.backup.tar.gz")])
    }
    option.None -> should.fail()
  }

  // Edge case 3: Param with multiple dots should preserve full value
  let param_multi_dot_request =
    create_test_request(Get, "/users/user.backup.tar")
  let param_multi_dot_result = find_route(test_router, param_multi_dot_request)
  case param_multi_dot_result {
    option.Some(#(_route, params)) -> {
      // Param should preserve full value for format detection
      // Even though we strip "tar" for matching, we store "user.backup.tar"
      params |> should.equal([#("id", "user.backup.tar")])
    }
    option.None -> should.fail()
  }

  // Edge case 4: Segment starting with dot (e.g., ".hidden")
  let hidden_request = create_test_request(Get, "/files/.hidden")
  let hidden_result = find_route(test_router, hidden_request)
  case hidden_result {
    option.Some(#(_route, params)) -> {
      // Should capture full segment
      params |> should.equal([#("filename", ".hidden")])
    }
    option.None -> should.fail()
  }

  // Edge case 5: Empty segment after extension stripping shouldn't match
  let empty_after_strip_request = create_test_request(Get, "/users/.json")
  let empty_after_strip_result =
    find_route(test_router, empty_after_strip_request)
  // This should probably not match, but if it does, param should be ".json"
  case empty_after_strip_result {
    option.Some(#(_route, params)) -> {
      // If it matches, should preserve full value
      params |> should.equal([#("id", ".json")])
    }
    option.None -> {
      // Or it might not match at all (empty segment after stripping)
      should.be_true(True)
    }
  }

  // Edge case 6: Multiple params with extensions
  let multi_param_request = create_test_request(Get, "/posts/123.json/comments")
  let multi_param_result = find_route(test_router, multi_param_request)
  case multi_param_result {
    option.Some(#(_route, params)) -> {
      // First param should preserve extension
      params |> should.equal([#("post_id", "123.json")])
    }
    option.None -> should.fail()
  }
}

pub fn extension_stripping_with_nested_routes_test() {
  // Test extension stripping with nested routes and multiple segments

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/api/v1/users/:id",
      controller: param_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/api/v1/posts/:post_id/comments/:comment_id",
      controller: param_handler,
      middleware: [],
    )

  // Test nested route with extension on first param
  let nested_request1 = create_test_request(Get, "/api/v1/users/123.json")
  let nested_result1 = find_route(test_router, nested_request1)
  case nested_result1 {
    option.Some(#(_route, params)) -> {
      params |> should.equal([#("id", "123.json")])
    }
    option.None -> should.fail()
  }

  // Test nested route with extension on last param
  let nested_request2 =
    create_test_request(Get, "/api/v1/posts/456/comments/789.csv")
  let nested_result2 = find_route(test_router, nested_request2)
  case nested_result2 {
    option.Some(#(_route, params)) -> {
      // Params are in reverse order (last param first)
      params |> should.equal([#("comment_id", "789.csv"), #("post_id", "456")])
    }
    option.None -> should.fail()
  }

  // Test nested route with extensions on both params
  let nested_request3 =
    create_test_request(Get, "/api/v1/posts/456.json/comments/789.csv")
  let nested_result3 = find_route(test_router, nested_request3)
  case nested_result3 {
    option.Some(#(_route, params)) -> {
      params
      |> should.equal([#("comment_id", "789.csv"), #("post_id", "456.json")])
    }
    option.None -> should.fail()
  }
}

pub fn extension_stripping_priority_test() {
  // Test that explicit extension pattern routes take precedence over extension stripping
  // e.g., /images/*.{jpg,png} should match before trying to strip extension from /images/photo.jpg

  let test_router =
    router()
    |> route(
      method: Get,
      path: "/images/*.{jpg,png}",
      controller: test_handler,
      middleware: [],
    )
    |> route(
      method: Get,
      path: "/images/:name",
      controller: param_handler,
      middleware: [],
    )

  // Test that /images/photo.jpg matches extension pattern route (not param route)
  let jpg_request = create_test_request(Get, "/images/photo.jpg")
  let jpg_result = find_route(test_router, jpg_request)

  case jpg_result {
    option.Some(#(_route, params)) -> {
      // Extension pattern should match (no params captured by extension patterns)
      params |> should.equal([])
    }
    option.None -> should.fail()
  }

  // Test that /images/document.pdf matches param route (extension stripping)
  let pdf_request = create_test_request(Get, "/images/document.pdf")
  let pdf_result = find_route(test_router, pdf_request)

  case pdf_result {
    option.Some(#(_route, params)) -> {
      // Should match /images/:name with extension stripping for matching,
      // but preserve full value in params for format detection
      params |> should.equal([#("name", "document.pdf")])
    }
    option.None -> should.fail()
  }
}
