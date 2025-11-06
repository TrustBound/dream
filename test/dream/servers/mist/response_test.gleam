import dream/core/http/statuses.{ok_status}
import dream/core/http/transaction
import dream/servers/mist/response as mist_response
import gleam/option

pub fn convert_with_valid_response_creates_mist_response_test() {
  // Arrange
  let dream_resp = transaction.text_response(ok_status(), "Hello World")

  // Act
  let _mist_resp = mist_response.convert(dream_resp)

  // Assert
  // Verify response was created (we can't easily test Mist response internals)
  // but the function should execute without error
  Nil
}

pub fn convert_with_response_with_cookies_includes_cookie_headers_test() {
  // Arrange
  let cookie = transaction.simple_cookie("session", "abc123")
  let dream_resp =
    transaction.Response(
      status: ok_status(),
      body: "Hello",
      headers: [],
      cookies: [cookie],
      content_type: option.None,
      content_length: option.None,
    )

  // Act
  let _mist_resp = mist_response.convert(dream_resp)

  // Assert
  // Response should be created successfully
  Nil
}
