import dream/context.{type AppContext}
import dream/dream
import dream/http/cookie.{cookie_name, cookie_value}
import dream/http/header.{Header}
import dream/http/request.{type Method, type Request, Get, Http, Http1, Request}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type EmptyServices, Route, Router, router}
import gleam/list
import gleam/option
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
  let test_route =
    Route(
      method: Get,
      path: "/test",
      controller: test_handler,
      middleware: [],
      streaming: False,
    )
  let test_router = Router(routes: [test_route])
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
  let empty_router = router
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
