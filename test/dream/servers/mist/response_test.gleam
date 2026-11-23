//// Tests for dream/servers/mist/response module.

import dream/http/cookie.{Cookie, Lax, None, secure_cookie, simple_cookie}
import dream/http/header.{Header}
import dream/http/response.{Response, Stream, Text}
import dream/servers/mist/response as mist_response
import dream_test/matchers.{
  be_equal, be_error, contain, contain_string, or_fail_with, should,
}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/mist_connection
import fixtures/panic_catcher
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/option
import gleam/yielder
import matchers/count_mist_headers.{count_mist_headers}
import matchers/extract_all_mist_header_values.{extract_all_mist_header_values}
import matchers/extract_mist_header_value.{extract_mist_header_value}
import matchers/have_mist_header.{have_mist_header}
import matchers/have_mist_header_containing.{have_mist_header_containing}
import mist

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("response", [
    convert_tests(),
    multiple_set_cookie_tests(),
    cookie_attribute_tests(),
    stream_tests(),
  ])
}

fn convert_tests() -> UnitNode {
  group("convert", [
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
      |> be_equal(200)
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

fn multiple_set_cookie_tests() -> UnitNode {
  group("multiple Set-Cookie headers (RFC 6265)", [
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
      |> be_equal(2)
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
      |> have_mist_header_containing("set-cookie", "theme=dark")
      |> or_fail_with("Should have theme cookie header")
    }),
    it("session cookie value is present in its own header", fn() {
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
      |> have_mist_header_containing("set-cookie", "session=abc123")
      |> or_fail_with("Should have session cookie header")
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
      |> be_equal(3)
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
        |> have_mist_header_containing("set-cookie", "session=abc123")
        |> or_fail_with("Cookie field cookie should be preserved")
      },
    ),
    it(
      "manual Set-Cookie in headers and cookies field produce two Set-Cookie headers",
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

        // Assert
        result
        |> should()
        |> count_mist_headers("set-cookie")
        |> be_equal(2)
        |> or_fail_with(
          "Manual Set-Cookie header and cookie field should both be present",
        )
      },
    ),
    it(
      "manual Set-Cookie in headers is preserved alongside cookies field",
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

        // Assert
        result
        |> should()
        |> have_mist_header_containing("set-cookie", "manual=fromheader")
        |> or_fail_with("Manual Set-Cookie header should be preserved")
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
      |> be_equal(1)
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
      |> extract_all_mist_header_values("set-cookie")
      |> contain("auth_token=secret123; Secure; HttpOnly; SameSite=Strict")
      |> or_fail_with(
        "Secure cookie should have all attributes in its own header",
      )
    }),
    it("cookies with attributes produce two Set-Cookie headers", fn() {
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

      // Assert
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> be_equal(2)
      |> or_fail_with("Both cookies should produce separate Set-Cookie headers")
    }),
    it("simple cookie is present alongside a secure cookie", fn() {
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

      // Assert
      result
      |> should()
      |> have_mist_header_containing("set-cookie", "preferences=lang=en")
      |> or_fail_with("Simple cookie should be present")
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
      |> have_mist_header("content-type", "text/html")
      |> or_fail_with("Content-type should be preserved")
    }),
    it("cookies alongside other headers produce two Set-Cookie headers", fn() {
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

      // Assert
      result
      |> should()
      |> count_mist_headers("set-cookie")
      |> be_equal(2)
      |> or_fail_with("Both cookies should be present")
    }),
    it("custom header is preserved alongside cookies", fn() {
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

      // Assert
      result
      |> should()
      |> have_mist_header("x-custom", "value1")
      |> or_fail_with("Custom header should be preserved")
    }),
    it("cache-control header is preserved alongside cookies", fn() {
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

      // Assert
      result
      |> should()
      |> have_mist_header("cache-control", "no-store")
      |> or_fail_with("Cache-Control should be preserved")
    }),
  ])
}

fn cookie_attribute_tests() -> UnitNode {
  group("cookie attributes", [
    it("writes Max-Age, Domain, Path and SameSite=Lax", fn() {
      // Arrange
      let cookie =
        Cookie(
          name: "id",
          value: "1",
          expires: option.None,
          max_age: option.Some(3600),
          domain: option.Some("example.com"),
          path: option.Some("/app"),
          secure: False,
          http_only: False,
          same_site: option.Some(Lax),
        )
      let dream_response = response_with_cookie(cookie)

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal(
        "id=1; Max-Age=3600; Domain=example.com; Path=/app; SameSite=Lax",
      )
      |> or_fail_with("Each attribute should be in the Set-Cookie header")
    }),
    it("writes SameSite=None", fn() {
      // Arrange
      let cookie =
        Cookie(
          name: "id",
          value: "1",
          expires: option.None,
          max_age: option.None,
          domain: option.None,
          path: option.None,
          secure: True,
          http_only: False,
          same_site: option.Some(None),
        )
      let dream_response = response_with_cookie(cookie)

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Secure; SameSite=None")
      |> or_fail_with("SameSite=None should follow Secure")
    }),
    it("writes Expires as an HTTP date", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(1_700_000_000))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Tue, 14 Nov 2023 22:13:20 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Tue, 14 Nov 2023 22:13:20 GMT",
      )
    }),
    it("writes Expires for the start of the Unix epoch", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(0))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Thu, 01 Jan 1970 00:00:00 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Thu, 01 Jan 1970 00:00:00 GMT",
      )
    }),
    it("writes Expires for a time before the Unix epoch", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(-1))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Wed, 31 Dec 1969 23:59:59 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Wed, 31 Dec 1969 23:59:59 GMT",
      )
    }),
    it("writes Expires for a date before 2000", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(915_148_799))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Thu, 31 Dec 1998 23:59:59 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Thu, 31 Dec 1998 23:59:59 GMT",
      )
    }),
    it("writes Expires for the leap day of 2000", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(951_782_400))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Tue, 29 Feb 2000 00:00:00 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Tue, 29 Feb 2000 00:00:00 GMT",
      )
    }),
    it("writes Expires for the leap day of 2024", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(1_709_208_000))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Thu, 29 Feb 2024 12:00:00 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Thu, 29 Feb 2024 12:00:00 GMT",
      )
    }),
    it("writes Expires for a date in July", fn() {
      // Arrange
      let dream_response = response_with_cookie(expiring_cookie(1_751_328_000))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Tue, 01 Jul 2025 00:00:00 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Tue, 01 Jul 2025 00:00:00 GMT",
      )
    }),
    it("writes Expires for the last second of year 9999", fn() {
      // Arrange
      let dream_response =
        response_with_cookie(expiring_cookie(253_402_300_799))

      // Act
      let result = mist_response.convert(dream_response)

      // Assert
      result
      |> should()
      |> extract_mist_header_value("set-cookie")
      |> be_equal("id=1; Expires=Fri, 31 Dec 9999 23:59:59 GMT")
      |> or_fail_with(
        "Expires should be the IMF-fixdate Fri, 31 Dec 9999 23:59:59 GMT",
      )
    }),
  ])
}

fn stream_tests() -> UnitNode {
  group("stream bodies", [
    it("convert panics for a stream body", fn() {
      // Arrange
      let dream_response =
        Response(
          status: 200,
          body: Stream(yielder.empty()),
          headers: [],
          cookies: [],
          content_type: option.None,
        )

      // Act
      let result =
        panic_catcher.catch_panic(fn() { mist_response.convert(dream_response) })

      // Assert
      result
      |> should()
      |> be_error()
      |> be_equal("Stream bodies must use convert_stream with mist request")
      |> or_fail_with("convert should panic with its message")
    }),
    it("convert_stream answers 400 when the chunk process cannot start", fn() {
      // Arrange
      let factory = mist_connection.start_refusing_factory()
      let #(connection, client) = mist_connection.open_connection(<<>>, factory)
      let request = mist_connection.request(connection, http.Get, "/", [])
      let dream_response = stream_response()

      // Act
      let result =
        mist_response.convert_stream(request, dream_response, yielder.empty())
      mist_connection.close_socket(client)
      mist_connection.stop_factory(factory)

      // Assert
      result.status
      |> should()
      |> be_equal(400)
      |> or_fail_with("mist answers 400 when it cannot start the process")
    }),
    it(
      "convert_stream stops reading the stream when a chunk cannot be sent",
      fn() {
        // Arrange
        let factory = mist_connection.start_accepting_factory()
        let #(connection, client) =
          mist_connection.open_connection(<<>>, factory)
        let request = mist_connection.request(connection, http.Get, "/", [])
        let reads = process.new_subject()
        let stream =
          yielder.repeatedly(fn() { read_after_client_left(connection, reads) })

        // Act
        let _response =
          mist_response.convert_stream(request, stream_response(), stream)
        let read_count = count_reads(reads, 0)
        mist_connection.close_socket(client)
        mist_connection.stop_factory(factory)

        // Assert
        read_count
        |> should()
        |> be_equal(1)
        |> or_fail_with("The stream should be read once, then stop")
      },
    ),
  ])
}

/// A cookie that sets only `Expires`, to `seconds_since_epoch`.
fn expiring_cookie(seconds_since_epoch: Int) -> cookie.Cookie {
  Cookie(
    name: "id",
    value: "1",
    expires: option.Some(seconds_since_epoch),
    max_age: option.None,
    domain: option.None,
    path: option.None,
    secure: False,
    http_only: False,
    same_site: option.None,
  )
}

fn response_with_cookie(cookie: cookie.Cookie) -> response.Response {
  Response(
    status: 200,
    body: Text(""),
    headers: [],
    cookies: [cookie],
    content_type: option.None,
  )
}

fn stream_response() -> response.Response {
  Response(
    status: 200,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// Closes the socket, as if the client went away, records one read and
/// gives a chunk.
fn read_after_client_left(
  connection: mist.Connection,
  reads: Subject(Nil),
) -> BitArray {
  mist_connection.close_connection_socket(connection)
  process.send(reads, Nil)
  <<"chunk":utf8>>
}

/// Counts reads until none comes for 300 ms. Stops at 5, because a stream
/// that never stops would read forever.
fn count_reads(reads: Subject(Nil), count: Int) -> Int {
  case count >= 5, process.receive(reads, 300) {
    True, _ -> count
    False, Ok(Nil) -> count_reads(reads, count + 1)
    False, Error(Nil) -> count
  }
}
