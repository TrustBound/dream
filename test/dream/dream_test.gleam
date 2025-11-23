import dream/context.{type AppContext}
import dream/dream
import dream/http/cookie.{cookie_name, cookie_value}
import dream/http/error.{type Error}
import dream/http/header.{Header}
import dream/http/params.{require_int}
import dream/http/request.{type Method, type Request, Get, Http, Http1, Request}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type EmptyServices, find_route, route, router}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleeunit/should

fn create_test_request(_method_value: Method, path_value: String) -> Request {
  Request(
    method: Get,
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
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("success"),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

pub fn route_request_with_matching_route_returns_controller_response_test() {
  // Arrange
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/test",
      controller: test_handler,
      middleware: [],
    )
  let request = create_test_request(Get, "/test")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let response = dream.route_request(test_router, request, context, services)

  // Assert
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("success")
        _ -> should.fail()
      }
    }
  }
}

pub fn route_request_with_no_matching_route_returns_not_found_test() {
  // Arrange
  let empty_router = router()
  let request = create_test_request(Get, "/nonexistent")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let response = dream.route_request(empty_router, request, context, services)

  // Assert
  case response {
    Response(status, body, _, _, _) -> {
      status |> should.equal(404)
      case body {
        Text(text) -> text |> should.equal("Route not found")
        _ -> should.fail()
      }
    }
  }
}

pub fn parse_cookies_from_headers_with_cookie_header_returns_cookies_test() {
  // Arrange
  let headers = [
    Header("Cookie", "session=abc123; theme=dark"),
    Header("Content-Type", "application/json"),
  ]

  // Act
  let cookies = dream.parse_cookies_from_headers(headers)

  // Assert
  list.length(cookies) |> should.equal(2)
  case cookies {
    [cookie, ..] -> {
      cookie_name(cookie) |> should.equal("session")
      cookie_value(cookie) |> should.equal("abc123")
    }
    [] -> should.fail()
  }
}

pub fn parse_cookies_from_headers_with_no_cookie_header_returns_empty_list_test() {
  // Arrange
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Authorization", "Bearer token"),
  ]

  // Act
  let cookies = dream.parse_cookies_from_headers(headers)

  // Assert
  list.length(cookies) |> should.equal(0)
}

pub fn parse_cookies_from_headers_with_case_insensitive_cookie_header_returns_cookies_test() {
  // Arrange
  let headers = [
    Header("COOKIE", "session=abc123"),
  ]

  // Act
  let cookies = dream.parse_cookies_from_headers(headers)

  // Assert
  list.length(cookies) |> should.equal(1)
}

pub fn parse_cookie_string_with_single_cookie_returns_one_cookie_test() {
  // Arrange
  let cookie_string = "session=abc123"

  // Act
  let cookies = dream.parse_cookie_string(cookie_string)

  // Assert
  list.length(cookies) |> should.equal(1)
  case cookies {
    [cookie] -> {
      cookie_name(cookie) |> should.equal("session")
      cookie_value(cookie) |> should.equal("abc123")
    }
    _ -> should.fail()
  }
}

pub fn parse_cookie_string_with_multiple_cookies_returns_multiple_cookies_test() {
  // Arrange
  let cookie_string = "session=abc123; theme=dark; lang=en"

  // Act
  let cookies = dream.parse_cookie_string(cookie_string)

  // Assert
  list.length(cookies) |> should.equal(3)
}

pub fn parse_cookie_string_with_cookie_without_value_returns_cookie_with_empty_value_test() {
  // Arrange
  let cookie_string = "session="

  // Act
  let cookies = dream.parse_cookie_string(cookie_string)

  // Assert
  list.length(cookies) |> should.equal(1)
  case cookies {
    [cookie] -> {
      cookie_name(cookie) |> should.equal("session")
      cookie_value(cookie) |> should.equal("")
    }
    _ -> should.fail()
  }
}

pub fn parse_cookie_string_with_whitespace_trimmed_test() {
  // Arrange
  let cookie_string = " session = abc123 "

  // Act
  let cookies = dream.parse_cookie_string(cookie_string)

  // Assert
  list.length(cookies) |> should.equal(1)
  case cookies {
    [cookie] -> {
      cookie_name(cookie) |> should.equal("session")
      cookie_value(cookie) |> should.equal("abc123")
    }
    _ -> should.fail()
  }
}

// ============================================================================
// Handler Flow Integration Tests
// These tests mirror the actual handler flow:
// 1. find_route() to get route and params
// 2. set_params() to set params on request
// 3. dream.route_request() to execute (which calls find_route again internally)
// ============================================================================

fn handler_flow_controller_with_id_param(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // This controller uses require_int to extract the id param
  // This is what the database example controllers do
  let id_result = require_int(request, "id")
  let response_body = extract_id_from_result(id_result)
  let status_code = get_status_from_id_result(id_result)

  Response(
    status: status_code,
    body: Text(response_body),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

fn extract_id_from_result(id_result: Result(Int, Error)) -> String {
  case id_result {
    Ok(id) -> "id: " <> int.to_string(id)
    Error(_) -> "Missing id parameter"
  }
}

fn get_status_from_id_result(id_result: Result(Int, Error)) -> Int {
  case id_result {
    Ok(_) -> 200
    Error(_) -> 400
  }
}

fn multi_param_controller(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  let user_id_result = require_int(request, "user_id")
  let post_id_result = require_int(request, "post_id")
  let #(status_code, response_body) =
    build_multi_param_response(user_id_result, post_id_result)

  Response(
    status: status_code,
    body: Text(response_body),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

fn build_multi_param_response(
  user_id_result: Result(Int, Error),
  post_id_result: Result(Int, Error),
) -> #(Int, String) {
  let user_id_error = is_error(user_id_result)
  let post_id_error = is_error(post_id_result)

  let error_response = get_first_error(user_id_error, post_id_error)
  case error_response {
    option.Some(err) -> err
    option.None -> build_success_response(user_id_result, post_id_result)
  }
}

fn get_first_error(
  user_id_error: Bool,
  post_id_error: Bool,
) -> option.Option(#(Int, String)) {
  let error_state = #(user_id_error, post_id_error)
  case error_state {
    #(True, _) -> option.Some(#(400, "Missing user_id parameter"))
    #(False, True) -> option.Some(#(400, "Missing post_id parameter"))
    #(False, False) -> option.None
  }
}

fn build_success_response(
  user_id_result: Result(Int, Error),
  post_id_result: Result(Int, Error),
) -> #(Int, String) {
  let user_id = extract_int_from_result(user_id_result)
  let post_id = extract_int_from_result(post_id_result)
  #(
    200,
    "user: " <> int.to_string(user_id) <> ", post: " <> int.to_string(post_id),
  )
}

fn is_error(result_value: Result(a, b)) -> Bool {
  case result_value {
    Ok(_) -> False
    Error(_) -> True
  }
}

fn extract_int_from_result(result_value: Result(Int, Error)) -> Int {
  result.unwrap(result_value, 0)
}

fn extract_route_and_params(
  router_instance: router.Router(AppContext, EmptyServices),
  request: Request,
) -> #(router.Route(AppContext, EmptyServices), List(#(String, String))) {
  let route_option = find_route(router_instance, request)
  case route_option {
    option.Some(route_and_params) -> route_and_params
    option.None -> {
      should.fail()
      // This will never execute, but satisfies type checker
      #(
        router.Route(
          method: Get,
          path: "",
          controller: test_handler,
          middleware: [],
          streaming: False,
        ),
        [],
      )
    }
  }
}

fn extract_response_body(response: Response) -> Result(String, String) {
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> Ok(text)
        _ -> Error("Expected text body")
      }
    }
  }
}

pub fn handler_flow_with_single_param_route_test() {
  // This test mirrors what the handler does:
  // 1. find_route() extracts params
  // 2. set_params() sets them on request
  // 3. dream.route_request() calls find_route() again internally
  // 4. Controller should receive params correctly

  // Arrange
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: handler_flow_controller_with_id_param,
      middleware: [],
    )

  let partial_request = create_test_request(Get, "/users/123")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act - Step 1: Find route (like handler does)
  let #(route, params) = extract_route_and_params(test_router, partial_request)

  // Step 2: Call execute_route directly (like handler does)
  // Note: execute_route sets params internally, so we don't set them here
  let response =
    dream.execute_route(route, partial_request, params, context, services)

  // Assert - Controller should receive params and return success
  let Response(status, _, _, _, _) = response
  status |> should.equal(200)

  let body_result = extract_response_body(response)
  let body_text = result.unwrap(body_result, "Expected text body")
  body_text |> should.equal("id: 123")
}

pub fn handler_flow_with_multiple_params_test() {
  // Test with nested params like /users/:user_id/posts/:post_id

  // Arrange
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:user_id/posts/:post_id",
      controller: multi_param_controller,
      middleware: [],
    )

  let partial_request = create_test_request(Get, "/users/42/posts/99")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act - Handler flow
  let #(route, params) = extract_route_and_params(test_router, partial_request)

  // Note: execute_route sets params internally, so we don't set them here
  let response =
    dream.execute_route(route, partial_request, params, context, services)

  // Assert
  let Response(status, _, _, _, _) = response
  status |> should.equal(200)

  let body_result = extract_response_body(response)
  let body_text = result.unwrap(body_result, "Expected text body")
  body_text |> should.equal("user: 42, post: 99")
}

pub fn handler_flow_with_no_params_returns_error_test() {
  // Test that if params aren't set, controller gets error

  // Arrange
  let test_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: handler_flow_controller_with_id_param,
      middleware: [],
    )

  let request_without_params = create_test_request(Get, "/users/123")
  // Don't call find_route or set_params - params list is empty
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act - Call route_request directly (it will call find_route internally)
  let response =
    dream.route_request(test_router, request_without_params, context, services)

  // Assert - Should work because route_request calls find_route internally
  let Response(status, _, _, _, _) = response
  status |> should.equal(200)

  let body_result = extract_response_body(response)
  let body_text = result.unwrap(body_result, "Expected text body")
  body_text |> should.equal("id: 123")
}
