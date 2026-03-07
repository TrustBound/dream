//// Tests for dream/servers/mist/response module.

import dream/http/cookie.{secure_cookie, simple_cookie}
import dream/http/header.{Header}
import dream/http/response.{Response, Text}
import dream/servers/mist/response as mist_response
import dream_test/assertions/should.{
  contain, contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option
import matchers/count_mist_headers.{count_mist_headers}
import matchers/extract_all_mist_header_values.{extract_all_mist_header_values}
import matchers/extract_mist_header_value.{extract_mist_header_value}
import matchers/have_mist_header.{have_mist_header}
import matchers/have_mist_header_containing.{have_mist_header_containing}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("response", [
    convert_tests(),
    multiple_set_cookie_tests(),
  ])
}

fn convert_tests() -> UnitTest {
  describe("convert", [
    it("preserves status code", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("Content-Type", "text/plain; charset=utf-8")],
          cookies: [],
          content_type: option.Some("text/plain; charset=utf-8"),
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result.status
      |> should()
      |> equal(200)
      |> or_fail_with("Status should be 200")
    }),
    it("includes custom headers", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("X-Custom-Header", "custom-value")],
          cookies: [],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header("x-custom-header", "custom-value")
      |> or_fail_with("Should have custom header")
    }),
    it("includes content-type header", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello World"),
          headers: [Header("Content-Type", "text/plain; charset=utf-8")],
          cookies: [],
          content_type: option.Some("text/plain; charset=utf-8"),
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header("content-type", "text/plain; charset=utf-8")
      |> or_fail_with("Should have content-type header")
    }),
    it("converts simple cookie to Set-Cookie header", fn() {
      // Arrange
      let cookie = simple_cookie("session", "abc123")
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header_containing("set-cookie", "session=abc123")
      |> or_fail_with("Should have session cookie")
    }),
    it("preserves other headers when cookie present", fn() {
      // Arrange
      let cookie = simple_cookie("session", "abc123")
      let dream_response =
        Response(
          status: 200,
          body: Text("Hello"),
          headers: [Header("X-Test", "value")],
          cookies: [cookie],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header("x-test", "value")
      |> or_fail_with("Should preserve X-Test header")
    }),
    it("preserves multiple headers", fn() {
      // Arrange
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

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header("x-request-id", "req-123")
      |> or_fail_with("Should have X-Request-ID header")
    }),
    it("preserves cache-control header", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 201,
          body: Text("Created"),
          headers: [Header("Cache-Control", "no-cache")],
          cookies: [],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> have_mist_header("cache-control", "no-cache")
      |> or_fail_with("Should have Cache-Control header")
    }),
    it("includes Secure attribute for secure cookie", fn() {
      // Arrange
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> contain_string("Secure")
      |> or_fail_with("Should have Secure attribute")
    }),
    it("includes HttpOnly attribute for secure cookie", fn() {
      // Arrange
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> contain_string("HttpOnly")
      |> or_fail_with("Should have HttpOnly attribute")
    }),
    it("includes SameSite=Strict attribute for secure cookie", fn() {
      // Arrange
      let cookie = secure_cookie("auth_token", "secret123")
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [cookie],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> contain_string("SameSite=Strict")
      |> or_fail_with("Should have SameSite=Strict attribute")
    }),
  ])
}

fn multiple_set_cookie_tests() -> UnitTest {
  describe("multiple Set-Cookie headers (RFC 6265)", [
    it("produces separate Set-Cookie headers for each cookie", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [
            simple_cookie("session", "abc123"),
            simple_cookie("theme", "dark"),
          ],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> equal(2)
      |> or_fail_with(
        "Each cookie must produce its own Set-Cookie header per RFC 6265",
      )
    }),
    it("each cookie value is individually present", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [
            simple_cookie("session", "abc123"),
            simple_cookie("theme", "dark"),
          ],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert — both cookie values appear as separate headers
      result
      |> should()
      |> have_mist_header_containing("set-cookie", "session=abc123")
      |> or_fail_with("Should have session cookie header")

      result
      |> should()
      |> have_mist_header_containing("set-cookie", "theme=dark")
      |> or_fail_with("Should have theme cookie header")
    }),
    it("three cookies produce three separate Set-Cookie headers", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [
            simple_cookie("a", "1"),
            simple_cookie("b", "2"),
            simple_cookie("c", "3"),
          ],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> equal(3)
      |> or_fail_with("Three cookies must produce three Set-Cookie headers")
    }),
    it(
      "manual Set-Cookie in headers coexists with cookies from cookies field",
      fn() {
        // Arrange — one cookie via headers, one via cookies field
        let dream_response =
          Response(
            status: 200,
            body: Text("OK"),
            headers: [Header("Set-Cookie", "manual=fromheader; Path=/")],
            cookies: [simple_cookie("session", "abc123")],
            content_type: option.None,
          )

        // Act
        let result = mist_response.convert(dream_response)

        // Assert — both must survive as separate headers
        result
        |> should()
        |> count_mist_headers("set-cookie")
        |> equal(2)
        |> or_fail_with(
          "Manual Set-Cookie header and cookie field should both be present",
        )

        result
        |> should()
        |> have_mist_header_containing("set-cookie", "manual=fromheader")
        |> or_fail_with("Manual Set-Cookie header should be preserved")

        result
        |> should()
        |> have_mist_header_containing("set-cookie", "session=abc123")
        |> or_fail_with("Cookie field cookie should be preserved")
      },
    ),
    it("duplicate non-set-cookie headers are still deduplicated", fn() {
      // Arrange — two headers with the same non-cookie name
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [
            Header("X-Request-ID", "first"),
            Header("X-Request-ID", "second"),
          ],
          cookies: [],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert — set_header replaces, so only the last value should remain
      result
      |> should()
      |> count_mist_headers("x-request-id")
      |> equal(1)
      |> or_fail_with(
        "Non-cookie duplicate headers should be deduplicated by set_header",
      )
    }),
    it("cookies with attributes each get their own header", fn() {
      // Arrange — mix of simple and secure cookies
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [],
          cookies: [
            simple_cookie("preferences", "lang=en"),
            secure_cookie("auth_token", "secret123"),
          ],
          content_type: option.None,
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert — both cookies present, secure one has its attributes
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> equal(2)
      |> or_fail_with("Both cookies should produce separate Set-Cookie headers")

      result
      |> should()
      |> have_mist_header_containing("set-cookie", "preferences=lang=en")
      |> or_fail_with("Simple cookie should be present")

      result
      |> should()
      |> extract_all_mist_header_values("set-cookie")
      |> contain("auth_token=secret123; Secure; HttpOnly; SameSite=Strict")
      |> or_fail_with(
        "Secure cookie should have all attributes in its own header",
      )
    }),
    it("cookies alongside other headers don't interfere", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Text("OK"),
          headers: [
            Header("X-Custom", "value1"),
            Header("Cache-Control", "no-store"),
          ],
          cookies: [
            simple_cookie("session", "abc"),
            simple_cookie("csrf", "token123"),
          ],
          content_type: option.Some("text/html"),
        )

      // Act
      let result = mist_response.convert(dream_response)

      // Assert — all headers coexist correctly
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> equal(2)
      |> or_fail_with("Both cookies should be present")

      result
      |> should()
      |> have_mist_header("x-custom", "value1")
      |> or_fail_with("Custom header should be preserved")

      result
      |> should()
      |> have_mist_header("cache-control", "no-store")
      |> or_fail_with("Cache-Control should be preserved")

      result
      |> should()
      |> have_mist_header("content-type", "text/html")
      |> or_fail_with("Content-type should be preserved")
    }),
  ])
}
