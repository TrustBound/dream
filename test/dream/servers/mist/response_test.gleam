//// Tests for dream/servers/mist/response module.

import dream/http/cookie.{secure_cookie, simple_cookie}
import dream/http/header.{Header}
import dream/http/response.{Response, Text}
import dream/servers/mist/response as mist_response
import dream_test/assertions/should.{
  be_ok, be_true, contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import test_helpers.{get_header_value, has_header, has_header_containing}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("response", [
    convert_tests(),
  ])
}

fn convert_tests() -> UnitTest {
  describe("convert", [
    it("preserves status code", fn() {
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("Content-Type", "text/plain; charset=utf-8")],
          cookies: [],
          content_type: option.Some("text/plain; charset=utf-8"),
        )

      mist_response.convert(dream_response).status
      |> should()
      |> equal(200)
      |> or_fail_with("Status should be 200")
    }),
    it("includes custom headers", fn() {
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("X-Custom-Header", "custom-value")],
          cookies: [],
          content_type: option.None,
        )

      has_header(
        mist_response.convert(dream_response),
        "x-custom-header",
        "custom-value",
      )
      |> should()
      |> be_true()
      |> or_fail_with("Should have custom header")
    }),
    it("includes content-type header", fn() {
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("Content-Type", "text/plain; charset=utf-8")],
          cookies: [],
          content_type: option.Some("text/plain; charset=utf-8"),
        )

      has_header(
        mist_response.convert(dream_response),
        "content-type",
        "text/plain; charset=utf-8",
      )
      |> should()
      |> be_true()
      |> or_fail_with("Should have content-type header")
    }),
    it("converts simple cookie to Set-Cookie header", fn() {
      let cookie = simple_cookie("session", "abc123")
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      has_header_containing(
        mist_response.convert(dream_response),
        "set-cookie",
        "session=abc123",
      )
      |> should()
      |> be_true()
      |> or_fail_with("Should have session cookie")
    }),
    it("preserves other headers when cookie present", fn() {
      let cookie = simple_cookie("session", "abc123")
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello"),
          headers: [Header("X-Test", "value")],
          cookies: [cookie],
          content_type: option.None,
        )

      has_header(mist_response.convert(dream_response), "x-test", "value")
      |> should()
      |> be_true()
      |> or_fail_with("Should preserve X-Test header")
    }),
    it("preserves multiple headers", fn() {
      let dream_response =
        Response(
          status: 201,
          body: Text("Created"),
          headers: [
            Header("X-Request-ID", "req-123"),
            Header("Cache-Control", "no-cache"),
            Header("X-API-Version", "v2"),
          ],
          cookies: [],
          content_type: option.Some("application/json"),
        )

      let mist_result = mist_response.convert(dream_response)

      has_header(mist_result, "x-request-id", "req-123")
      |> should()
      |> be_true()
      |> or_fail_with("Should have X-Request-ID header")
    }),
    it("preserves cache-control header", fn() {
      let dream_response =
        Response(
          status: 201,
          body: Text("Created"),
          headers: [Header("Cache-Control", "no-cache")],
          cookies: [],
          content_type: option.None,
        )

      has_header(
        mist_response.convert(dream_response),
        "cache-control",
        "no-cache",
      )
      |> should()
      |> be_true()
      |> or_fail_with("Should have Cache-Control header")
    }),
    it("includes Secure attribute for secure cookie", fn() {
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      get_header_value(mist_response.convert(dream_response), "set-cookie")
      |> should()
      |> be_ok()
      |> contain_string("Secure")
      |> or_fail_with("Should have Secure attribute")
    }),
    it("includes HttpOnly attribute for secure cookie", fn() {
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      get_header_value(mist_response.convert(dream_response), "set-cookie")
      |> should()
      |> be_ok()
      |> contain_string("HttpOnly")
      |> or_fail_with("Should have HttpOnly attribute")
    }),
    it("includes SameSite=Strict attribute for secure cookie", fn() {
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      get_header_value(mist_response.convert(dream_response), "set-cookie")
      |> should()
      |> be_ok()
      |> contain_string("SameSite=Strict")
      |> or_fail_with("Should have SameSite=Strict attribute")
    }),
  ])
}
