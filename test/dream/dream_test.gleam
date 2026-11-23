//// Tests for dream/dream module.

import dream/context.{AppContext}
import dream/dream
import dream/http/cookie
import dream/http/header.{Header}
import dream/http/request.{Get}
import dream/router.{EmptyServices, route, router}
import dream/servers/mist/server
import dream_test/matchers.{
  be_empty, be_equal, be_error, have_length, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/handler.{id_param_handler, multi_param_handler, test_handler}
import fixtures/panic_catcher
import fixtures/request as test_request
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_cookie_name.{extract_cookie_name}
import matchers/extract_cookie_value.{extract_cookie_value}
import matchers/extract_response_status.{extract_response_status}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("dream", [
    route_request_tests(),
    parse_cookies_tests(),
    handler_flow_tests(),
    cookie_string_tests(),
    get_server_tests(),
  ])
}

fn route_request_tests() -> UnitNode {
  group("route_request", [
    it("returns controller response for matching route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/test", test_handler, [])
      let request = test_request.create_request(Get, "/test")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(test_router, request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("test")
      |> or_fail_with("Should return controller response body")
    }),
    it("returns 404 for no matching route", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/nonexistent")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(router(), request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("Should return 404 status")
    }),
    it("returns 'Route not found' body for no matching route", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/nonexistent")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(router(), request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Route not found")
      |> or_fail_with("Should return 'Route not found' body")
    }),
  ])
}

fn parse_cookies_tests() -> UnitNode {
  group("parse_cookies_from_headers", [
    it("parses cookies from Cookie header", fn() {
      // Arrange
      let headers = [
        Header("Cookie", "session=abc123; theme=dark"),
        Header("Content-Type", "application/json"),
      ]

      // Act
      let result = dream.parse_cookies_from_headers(headers)

      // Assert
      result
      |> should()
      |> have_length(2)
      |> or_fail_with("Should parse 2 cookies")
    }),
    it("extracts first cookie name correctly", fn() {
      // Arrange
      let headers = [Header("Cookie", "session=abc123; theme=dark")]

      // Act
      let result = dream.parse_cookies_from_headers(headers)

      // Assert
      result
      |> should()
      |> extract_cookie_name()
      |> be_equal("session")
      |> or_fail_with("First cookie should be 'session'")
    }),
    it("extracts first cookie value correctly", fn() {
      // Arrange
      let headers = [Header("Cookie", "session=abc123; theme=dark")]

      // Act
      let result = dream.parse_cookies_from_headers(headers)

      // Assert
      result
      |> should()
      |> extract_cookie_value()
      |> be_equal("abc123")
      |> or_fail_with("First cookie value should be 'abc123'")
    }),
    it("returns empty list when no Cookie header", fn() {
      // Arrange
      let headers = [
        Header("Content-Type", "application/json"),
        Header("Authorization", "Bearer token"),
      ]

      // Act
      let result = dream.parse_cookies_from_headers(headers)

      // Assert
      result
      |> should()
      |> be_empty()
      |> or_fail_with("Should return empty list")
    }),
    it("handles case-insensitive Cookie header", fn() {
      // Arrange
      let headers = [Header("COOKIE", "session=abc123")]

      // Act
      let result = dream.parse_cookies_from_headers(headers)

      // Assert
      result
      |> should()
      |> have_length(1)
      |> or_fail_with("Should parse cookie with uppercase header")
    }),
    group("parse_cookie_string", [
      it("parses single cookie", fn() {
        // Arrange
        let cookie_string = "session=abc123"

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> have_length(1)
        |> or_fail_with("Should parse single cookie")
      }),
      it("extracts cookie name from single cookie", fn() {
        // Arrange
        let cookie_string = "session=abc123"

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> extract_cookie_name()
        |> be_equal("session")
        |> or_fail_with("Cookie name should be 'session'")
      }),
      it("extracts cookie value from single cookie", fn() {
        // Arrange
        let cookie_string = "session=abc123"

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> extract_cookie_value()
        |> be_equal("abc123")
        |> or_fail_with("Cookie value should be 'abc123'")
      }),
      it("parses multiple cookies", fn() {
        // Arrange
        let cookie_string = "session=abc123; theme=dark; lang=en"

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> have_length(3)
        |> or_fail_with("Should parse 3 cookies")
      }),
      it("handles cookie with empty value", fn() {
        // Arrange
        let cookie_string = "session="

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> extract_cookie_value()
        |> be_equal("")
        |> or_fail_with("Cookie value should be empty string")
      }),
      it("trims whitespace from cookie name and value", fn() {
        // Arrange
        let cookie_string = " session = abc123 "

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> extract_cookie_name()
        |> be_equal("session")
        |> or_fail_with("Cookie name should be trimmed")
      }),
      it("keeps a cookie value that contains an equals sign", fn() {
        // Arrange
        let cookie_string = "token=abc=="

        // Act
        let result = dream.parse_cookie_string(cookie_string)

        // Assert
        result
        |> should()
        |> extract_cookie_value()
        |> be_equal("abc==")
        |> or_fail_with("Cookie value should be 'abc=='")
      }),
    ]),
  ])
}

fn handler_flow_tests() -> UnitNode {
  group("handler flow", [
    it("extracts single param and returns 200 status", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id", id_param_handler, [])
      let request = test_request.create_request(Get, "/users/123")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(test_router, request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(200)
      |> or_fail_with("Status should be 200")
    }),
    it("extracts single param value correctly", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id", id_param_handler, [])
      let request = test_request.create_request(Get, "/users/123")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(test_router, request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("id: 123")
      |> or_fail_with("Body should be 'id: 123'")
    }),
    it("extracts multiple params via route_request", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:user_id/posts/:post_id", multi_param_handler, [])
      let request = test_request.create_request(Get, "/users/42/posts/99")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(test_router, request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("user: 42, post: 99")
      |> or_fail_with("Body should contain both params")
    }),
    it("route_request finds and executes route with params", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id", id_param_handler, [])
      let request = test_request.create_request(Get, "/users/123")
      let context = AppContext(request_id: "test-id")

      // Act
      let response =
        dream.route_request(test_router, request, context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("id: 123")
      |> or_fail_with("route_request should find route and extract params")
    }),
  ])
}

fn cookie_string_tests() -> UnitNode {
  group("parse_cookie_string", [
    it("gives a cookie without = an empty value", fn() {
      // Arrange
      let cookie_string = "theme=dark; flag"

      // Act
      let cookies = dream.parse_cookie_string(cookie_string)

      // Assert
      cookies
      |> should()
      |> be_equal([
        cookie.simple_cookie("theme", "dark"),
        cookie.simple_cookie("flag", ""),
      ])
      |> or_fail_with("flag has no = so its value is empty")
    }),
  ])
}

fn get_server_tests() -> UnitNode {
  group("get_server", [
    it("panics when the risks are not understood", fn() {
      // Arrange
      let dream_instance = server.new()

      // Act
      let result =
        panic_catcher.catch_panic(fn() {
          dream.get_server(dream_instance, risks_understood: False)
        })

      // Assert
      result
      |> should()
      |> be_error()
      |> be_equal(
        "dream.get_server() requires risks_understood: True. This function breaks Dream's server abstraction and couples your code to Mist. Read the documentation to understand the risks before proceeding.",
      )
      |> or_fail_with("get_server should panic with its documented message")
    }),
  ])
}
