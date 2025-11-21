import dream/http/cookie.{secure_cookie, simple_cookie}
import dream/http/header.{Header}
import dream/http/response.{Response, Text}
import dream/servers/mist/response as mist_response
import gleam/option
import gleam/string
import gleeunit/should
import test_helpers.{get_header_value, has_header, has_header_containing}

pub fn convert_with_valid_response_creates_mist_response_test() {
  // Arrange - construct response with multiple elements to verify conversion
  let dream_resp =
    Response(
      status: 200,
      body: Text("Hello World"),
      headers: [
        Header("Content-Type", "text/plain; charset=utf-8"),
        Header("X-Custom-Header", "custom-value"),
      ],
      cookies: [],
      content_type: option.Some("text/plain; charset=utf-8"),
    )

  // Act
  let mist_resp = mist_response.convert(dream_resp)

  // Assert - verify all conversions happened correctly
  mist_resp.status |> should.equal(200)
  has_header(mist_resp, "x-custom-header", "custom-value") |> should.be_true()
  has_header(mist_resp, "content-type", "text/plain; charset=utf-8")
  |> should.be_true()
}

pub fn convert_with_response_with_cookies_includes_cookie_headers_test() {
  // Arrange - response with cookie to verify cookie → Set-Cookie conversion
  let cookie = simple_cookie("session", "abc123")
  let dream_resp =
    Response(
      status: 200,
      body: Text("Hello"),
      headers: [Header("X-Test", "value")],
      cookies: [cookie],
      content_type: option.None,
    )

  // Act
  let mist_resp = mist_response.convert(dream_resp)

  // Assert - verify cookie was converted to Set-Cookie header
  mist_resp.status |> should.equal(200)
  has_header_containing(mist_resp, "set-cookie", "session=abc123")
  |> should.be_true()
  has_header(mist_resp, "x-test", "value") |> should.be_true()
}

pub fn convert_with_multiple_headers_preserves_all_headers_test() {
  // Arrange - response with multiple headers to verify all are converted
  let dream_resp =
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
  let mist_resp = mist_response.convert(dream_resp)

  // Assert - verify all headers made it through
  mist_resp.status |> should.equal(201)
  has_header(mist_resp, "x-request-id", "req-123") |> should.be_true()
  has_header(mist_resp, "cache-control", "no-cache") |> should.be_true()
  has_header(mist_resp, "x-api-version", "v2") |> should.be_true()
  has_header(mist_resp, "content-type", "application/json") |> should.be_true()
}

pub fn convert_with_secure_cookie_includes_cookie_attributes_test() {
  // Arrange - secure cookie to verify attributes are in Set-Cookie header
  let cookie = secure_cookie("auth_token", "secret123")
  let dream_resp =
    Response(
      status: 200,
      body: Text("OK"),
      headers: [],
      cookies: [cookie],
      content_type: option.None,
    )

  // Act
  let mist_resp = mist_response.convert(dream_resp)

  // Assert - verify secure cookie attributes in header
  mist_resp.status |> should.equal(200)

  case get_header_value(mist_resp, "set-cookie") {
    Ok(cookie_value) -> {
      string.contains(cookie_value, "auth_token=secret123") |> should.be_true()
      string.contains(cookie_value, "Secure") |> should.be_true()
      string.contains(cookie_value, "HttpOnly") |> should.be_true()
      string.contains(cookie_value, "SameSite=Strict") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}
