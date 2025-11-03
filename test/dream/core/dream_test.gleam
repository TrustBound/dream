import dream/core/context.{type AppContext, new_context}
import dream/core/dream
import dream/core/http/statuses.{not_found_status, ok_status}
import dream/core/http/transaction
import dream/core/router.{Route, Router, router}
import gleam/list
import gleam/option
import gleeunit/should

fn create_test_request(
  method_value: transaction.Method,
  path_value: String,
) -> transaction.Request(AppContext) {
  transaction.Request(
    method: method_value,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: path_value,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: new_context("test-id"),
  )
}

fn test_handler(
  _request: transaction.Request(AppContext),
) -> transaction.Response {
  transaction.text_response(ok_status(), "success")
}

pub fn route_request_with_matching_route_returns_handler_response_test() {
  // Arrange
  let test_route =
    Route(
      method: transaction.Get,
      path: "/test",
      handler: test_handler,
      middleware: [],
    )
  let test_router = Router(routes: [test_route])
  let request = create_test_request(transaction.Get, "/test")

  // Act
  let response = dream.route_request(test_router, request)

  // Assert
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("success")
    }
  }
}

pub fn route_request_with_no_matching_route_returns_not_found_test() {
  // Arrange
  let empty_router = router
  let request = create_test_request(transaction.Get, "/nonexistent")

  // Act
  let response = dream.route_request(empty_router, request)

  // Assert
  case response {
    transaction.Response(status, body, _, _, _, _) -> {
      status |> should.equal(not_found_status())
      body |> should.equal("Route not found")
    }
  }
}

pub fn parse_cookies_from_headers_with_cookie_header_returns_cookies_test() {
  // Arrange
  let headers = [
    transaction.Header("Cookie", "session=abc123; theme=dark"),
    transaction.Header("Content-Type", "application/json"),
  ]

  // Act
  let cookies = dream.parse_cookies_from_headers(headers)

  // Assert
  list.length(cookies) |> should.equal(2)
  case cookies {
    [cookie, ..] -> {
      transaction.cookie_name(cookie) |> should.equal("session")
      transaction.cookie_value(cookie) |> should.equal("abc123")
    }
    [] -> should.fail()
  }
}

pub fn parse_cookies_from_headers_with_no_cookie_header_returns_empty_list_test() {
  // Arrange
  let headers = [
    transaction.Header("Content-Type", "application/json"),
    transaction.Header("Authorization", "Bearer token"),
  ]

  // Act
  let cookies = dream.parse_cookies_from_headers(headers)

  // Assert
  list.length(cookies) |> should.equal(0)
}

pub fn parse_cookies_from_headers_with_case_insensitive_cookie_header_returns_cookies_test() {
  // Arrange
  let headers = [
    transaction.Header("COOKIE", "session=abc123"),
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
      transaction.cookie_name(cookie) |> should.equal("session")
      transaction.cookie_value(cookie) |> should.equal("abc123")
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
      transaction.cookie_name(cookie) |> should.equal("session")
      transaction.cookie_value(cookie) |> should.equal("")
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
      transaction.cookie_name(cookie) |> should.equal("session")
      transaction.cookie_value(cookie) |> should.equal("abc123")
    }
    _ -> should.fail()
  }
}
