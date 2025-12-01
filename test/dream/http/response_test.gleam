//// Tests for dream/http/response module.

import dream/http/header.{Header}
import dream/http/response.{
  Text, empty_response, html_response, json_response, redirect_response,
  text_response,
}
import dream/http/status
import dream_test/assertions/should.{be_some, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}

// ============================================================================
// Helper Functions
// ============================================================================

fn extract_body_text(response: response.Response) -> String {
  case response.body {
    Text(text) -> text
    _ -> ""
  }
}

fn get_first_header_value(response: response.Response) -> String {
  case response.headers {
    [Header(_, value), ..] -> value
    _ -> ""
  }
}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("response", [
    describe("json_response", [
      it("sets status correctly", fn() {
        let body = "{\"message\": \"Hello\"}"

        json_response(status.ok, body).status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to application/json", fn() {
        let body = "{\"message\": \"Hello\"}"

        json_response(status.ok, body).content_type
        |> should()
        |> be_some()
        |> equal("application/json; charset=utf-8")
        |> or_fail_with("Content type should be JSON")
      }),
      it("sets body text", fn() {
        let body = "{\"message\": \"Hello\"}"

        extract_body_text(json_response(status.ok, body))
        |> should()
        |> equal(body)
        |> or_fail_with("Body should match input")
      }),
    ]),
    describe("html_response", [
      it("sets status correctly", fn() {
        html_response(status.ok, "<h1>Hello</h1>").status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to text/html", fn() {
        html_response(status.ok, "<h1>Hello</h1>").content_type
        |> should()
        |> be_some()
        |> equal("text/html; charset=utf-8")
        |> or_fail_with("Content type should be HTML")
      }),
    ]),
    describe("text_response", [
      it("sets status correctly", fn() {
        text_response(status.ok, "Hello").status
        |> should()
        |> equal(200)
        |> or_fail_with("Status should be 200")
      }),
      it("sets content type to text/plain", fn() {
        text_response(status.ok, "Hello").content_type
        |> should()
        |> be_some()
        |> equal("text/plain; charset=utf-8")
        |> or_fail_with("Content type should be plain text")
      }),
    ]),
    describe("redirect_response", [
      it("sets status to redirect code", fn() {
        redirect_response(status.found, "/users/123").status
        |> should()
        |> equal(302)
        |> or_fail_with("Status should be 302")
      }),
      it("sets Location header", fn() {
        get_first_header_value(redirect_response(status.found, "/users/123"))
        |> should()
        |> equal("/users/123")
        |> or_fail_with("Location header should be set")
      }),
    ]),
    describe("empty_response", [
      it("sets status correctly", fn() {
        empty_response(status.no_content).status
        |> should()
        |> equal(204)
        |> or_fail_with("Status should be 204")
      }),
      it("has empty body", fn() {
        extract_body_text(empty_response(status.no_content))
        |> should()
        |> equal("")
        |> or_fail_with("Body should be empty")
      }),
    ]),
  ])
}
