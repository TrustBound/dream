//// Tests for dream/dream module.

import dream/context.{AppContext}
import dream/dream
import dream/http/header.{Header}
import dream/http/request.{Get}
import dream/router.{EmptyServices, route, router}
import dream_test/assertions/should.{
  be_empty, equal, have_length, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{id_param_handler, multi_param_handler, test_handler}
import fixtures/request as test_request
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_cookie_name.{extract_cookie_name}
import matchers/extract_cookie_value.{extract_cookie_value}
import matchers/extract_response_status.{extract_response_status}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("dream", [
    route_request_tests(),
    parse_cookies_tests(),
    handler_flow_tests(),
  ])
}

fn route_request_tests() -> UnitTest {
  describe("route_request", [
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
      |> equal("test")
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
      |> equal(404)
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
      |> equal("Route not found")
      |> or_fail_with("Should return 'Route not found' body")
    }),
  ])
}

fn parse_cookies_tests() -> UnitTest {
  describe("parse_cookies_from_headers", [
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
      |> equal("session")
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
      |> equal("abc123")
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
    describe("parse_cookie_string", [
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
        |> equal("session")
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
        |> equal("abc123")
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
        |> equal("")
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
        |> equal("session")
        |> or_fail_with("Cookie name should be trimmed")
      }),
    ]),
  ])
}

fn handler_flow_tests() -> UnitTest {
  describe("handler flow", [
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
      |> equal(200)
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
      |> equal("id: 123")
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
      |> equal("user: 42, post: 99")
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
      |> equal("id: 123")
      |> or_fail_with("route_request should find route and extract params")
    }),
  ])
}
