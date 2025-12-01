//// Tests for dream/http/response module.

import dream/http/response.{
  empty_response, html_response, json_response, redirect_response, text_response,
}
import dream/http/status
import dream_test/assertions/should.{be_some, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_first_header_value.{extract_first_header_value}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("response", [
    describe("json_response", [
      it("sets status correctly", fn() {
        // Arrange
        let body = "{\"message\": \"Hello\"}"

        // Act
        let response = json_response(status.ok, body)

        // Assert
        response.status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to application/json", fn() {
        // Arrange
        let body = "{\"message\": \"Hello\"}"

        // Act
        let response = json_response(status.ok, body)

        // Assert
        response.content_type
        |> should()
        |> be_some()
        |> equal("application/json; charset=utf-8")
        |> or_fail_with("Content type should be JSON")
      }),
      it("sets body text", fn() {
        // Arrange
        let body = "{\"message\": \"Hello\"}"

        // Act
        let response = json_response(status.ok, body)

        // Assert
        response
        |> should()
        |> extract_body_text()
        |> equal(body)
        |> or_fail_with("Body should match input")
      }),
    ]),
    describe("html_response", [
      it("sets status correctly", fn() {
        // Arrange
        let html = "<h1>Hello</h1>"

        // Act
        let response = html_response(status.ok, html)

        // Assert
        response.status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to text/html", fn() {
        // Arrange
        let html = "<h1>Hello</h1>"

        // Act
        let response = html_response(status.ok, html)

        // Assert
        response.content_type
        |> should()
        |> be_some()
        |> equal("text/html; charset=utf-8")
        |> or_fail_with("Content type should be HTML")
      }),
    ]),
    describe("text_response", [
      it("sets status correctly", fn() {
        // Arrange
        let text = "Hello"

        // Act
        let response = text_response(status.ok, text)

        // Assert
        response.status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to text/plain", fn() {
        // Arrange
        let text = "Hello"

        // Act
        let response = text_response(status.ok, text)

        // Assert
        response.content_type
        |> should()
        |> be_some()
        |> equal("text/plain; charset=utf-8")
        |> or_fail_with("Content type should be plain text")
      }),
    ]),
    describe("redirect_response", [
      it("sets status to redirect code", fn() {
        // Arrange
        let location = "/users/123"

        // Act
        let response = redirect_response(status.found, location)

        // Assert
        response.status
        |> should()
        |> equal(302)
        |> or_fail_with("Status should be 302")
      }),
      it("sets Location header", fn() {
        // Arrange
        let location = "/users/123"

        // Act
        let response = redirect_response(status.found, location)

        // Assert
        response.headers
        |> should()
        |> extract_first_header_value()
        |> equal(location)
        |> or_fail_with("Location header should be set")
      }),
    ]),
    describe("empty_response", [
      it("sets status correctly", fn() {
        // Act
        let response = empty_response(status.no_content)

        // Assert
        response.status
        |> should()
        |> equal(204)
        |> or_fail_with("Status should be 204")
      }),
      it("has empty body", fn() {
        // Act
        let response = empty_response(status.no_content)

        // Assert
        response
        |> should()
        |> extract_body_text()
        |> equal("")
        |> or_fail_with("Body should be empty")
      }),
    ]),
  ])
}
