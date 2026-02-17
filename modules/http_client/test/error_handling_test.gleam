//// Error handling tests for HTTP client
////
//// Tests that verify errors are properly surfaced through all APIs:
//// - send() with error status codes
//// - send() with large responses
//// - send() with empty responses
//// - stream_yielder() with connection drops
//// - stream_messages() with connection drops
//// - Connection failures (non-existent server)

import dream_http_client/client
import dream_http_client_test
import gleam/http
import gleam/io
import gleam/list
import gleam/string
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

// ============================================================================
// send() Error Status Code Tests
// ============================================================================

/// Test: send() returns ResponseError with 404 status
pub fn send_404_status_test() {
  // Arrange
  let req = mock_request("/status/404")

  // Act
  let result = client.send(req)

  // Assert - 404 comes back as ResponseError with full response
  case result {
    Error(client.ResponseError(response: client.HttpResponse(
      status: status,
      body: body,
      ..,
    ))) -> {
      status |> should.equal(404)
      string.contains(body, "404") |> should.be_true()
    }
    Error(client.RequestError(message: error_reason)) -> {
      io.println(
        "send_404_status_test encountered connection-level error: "
        <> error_reason,
      )
    }
    Ok(_) -> {
      io.println("send_404_status_test: expected error, got Ok")
      should.fail()
    }
  }
}

/// Test: send() returns ResponseError with 500 status
pub fn send_500_status_test() {
  // Arrange
  let req = mock_request("/status/500")

  // Act
  let result = client.send(req)

  // Assert - 500 comes back as ResponseError with full response
  case result {
    Error(client.ResponseError(response: client.HttpResponse(
      status: status,
      body: body,
      ..,
    ))) -> {
      status |> should.equal(500)
      string.contains(body, "500") |> should.be_true()
    }
    Error(client.RequestError(message: error_reason)) -> {
      io.println(
        "send_500_status_test encountered connection-level error: "
        <> error_reason,
      )
    }
    Ok(_) -> {
      io.println("send_500_status_test: expected error, got Ok")
      should.fail()
    }
  }
}

/// Test: send() returns ResponseError with 400 status
pub fn send_400_status_test() {
  // Arrange
  let req = mock_request("/status/400")

  // Act
  let result = client.send(req)

  // Assert - 400 comes back as ResponseError with full response
  case result {
    Error(client.ResponseError(response: client.HttpResponse(
      status: status,
      body: body,
      ..,
    ))) -> {
      status |> should.equal(400)
      string.contains(body, "400") |> should.be_true()
    }
    Error(client.RequestError(message: error_reason)) -> {
      io.println(
        "send_400_status_test encountered connection-level error: "
        <> error_reason,
      )
    }
    Ok(_) -> {
      io.println("send_400_status_test: expected error, got Ok")
      should.fail()
    }
  }
}

/// Test: send() returns RequestError on connection failure
pub fn send_connection_failure_test() {
  // Arrange - Use a port that won't have a server listening
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(19_999)
    |> client.path("/nonexistent")

  // Act
  let result = client.send(req)

  // Assert - Should get a RequestError (transport failure)
  case result {
    Error(client.RequestError(message: error_msg)) -> {
      string.length(error_msg) |> should.not_equal(0)
    }
    Error(client.ResponseError(_)) -> {
      io.println("Expected RequestError, got ResponseError")
      should.fail()
    }
    Ok(_) -> should.fail()
  }
}

/// Test: requests with body do not hardcode Content-Type
///
/// Regression test for the Erlang httpc shim: it must respect the caller's
/// `Content-Type` header when building the `{Url, Headers, ContentType, Body}`
/// request tuple (and never force `application/json`).
pub fn send_respects_explicit_request_content_type_test() {
  let req =
    client.new()
    |> client.method(http.Post)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(dream_http_client_test.get_test_port())
    |> client.path("/content-type")
    |> client.add_header("Content-Type", "text/plain")
    |> client.body("hello")

  case client.send(req) {
    Ok(client.HttpResponse(body: body, ..)) ->
      body |> should.equal("text/plain")
    Error(client.ResponseError(response: client.HttpResponse(status: status, ..))) -> {
      io.println(
        "send_respects_explicit_request_content_type_test got HTTP error: "
        <> string.inspect(status),
      )
      False |> should.be_true()
    }
    Error(client.RequestError(message: error_reason)) -> {
      io.println(
        "send_respects_explicit_request_content_type_test failed: "
        <> error_reason,
      )
      False |> should.be_true()
    }
  }
}

/// Test: send() handles large responses correctly
pub fn send_large_response_test() {
  // Arrange - ~1MB response
  let req = mock_request("/large")

  // Act
  let result = client.send(req)

  // Assert - Should successfully get the large body
  case result {
    Ok(client.HttpResponse(body: body, ..)) -> {
      // Should be at least 100KB
      string.length(body) |> should.not_equal(0)
      { string.length(body) > 100_000 } |> should.be_true()
    }
    Error(error) -> {
      io.println(
        "Expected large response to succeed, got error: "
        <> string.inspect(error),
      )
      should.fail()
    }
  }
}

/// Test: send() handles empty responses correctly
pub fn send_empty_response_test() {
  // Arrange
  let req = mock_request("/empty")

  // Act
  let result = client.send(req)

  // Assert - Empty body is not an error
  case result {
    Ok(client.HttpResponse(body: body, ..)) -> {
      body |> should.equal("")
    }
    Error(error) -> {
      io.println(
        "Expected empty response to succeed, got error: "
        <> string.inspect(error),
      )
      should.fail()
    }
  }
}

// ============================================================================
// Error Message Quality Tests
// ============================================================================

// ============================================================================
// HttpResponse Field Verification Tests
// ============================================================================

/// Test: successful response includes status code 200
pub fn send_success_includes_status_code_test() {
  let req = mock_request("/text")
  let assert Ok(client.HttpResponse(status: status, body: body, ..)) =
    client.send(req)
  status |> should.equal(200)
  body |> should.equal("Hello, World!")
}

/// Test: successful response includes headers as List(Header)
pub fn send_success_includes_headers_test() {
  let req = mock_request("/json")
  let assert Ok(client.HttpResponse(headers: headers, ..)) = client.send(req)

  // Should have at least one header
  { headers != [] } |> should.be_true()

  // Headers should be Header type with name/value
  let has_content_type =
    list.any(headers, fn(h: client.Header) {
      string.lowercase(h.name) == "content-type"
    })
  has_content_type |> should.be_true()
}

/// Test: error response includes headers in ResponseError
pub fn send_error_response_includes_headers_test() {
  let req = mock_request("/status/404")
  case client.send(req) {
    Error(client.ResponseError(response: client.HttpResponse(
      headers: headers,
      ..,
    ))) -> {
      // Error responses should also carry headers
      { headers != [] } |> should.be_true()
      let has_content_type =
        list.any(headers, fn(h: client.Header) {
          string.lowercase(h.name) == "content-type"
        })
      has_content_type |> should.be_true()
    }
    Error(client.RequestError(message: msg)) -> {
      io.println("Connection error (mock server down?): " <> msg)
    }
    Ok(_) -> {
      io.println("Expected ResponseError for 404, got Ok")
      should.fail()
    }
  }
}

// ============================================================================
// Status Code Boundary Tests
// ============================================================================

/// Test: status 200 returns Ok
pub fn send_status_200_returns_ok_test() {
  let req = mock_request("/status/200")
  let assert Ok(client.HttpResponse(status: status, ..)) = client.send(req)
  status |> should.equal(200)
}

/// Test: status 201 returns Ok
pub fn send_status_201_returns_ok_test() {
  let req = mock_request("/status/201")
  let assert Ok(client.HttpResponse(status: status, ..)) = client.send(req)
  status |> should.equal(201)
}

/// Test: status 204 returns Ok
pub fn send_status_204_returns_ok_test() {
  let req = mock_request("/status/204")
  let assert Ok(client.HttpResponse(status: status, ..)) = client.send(req)
  status |> should.equal(204)
}

/// Test: status 399 returns Ok (just below the error boundary)
pub fn send_status_399_returns_ok_test() {
  let req = mock_request("/status/399")
  let assert Ok(client.HttpResponse(status: status, ..)) = client.send(req)
  status |> should.equal(399)
}

/// Test: status 400 returns Error (exactly at the error boundary)
pub fn send_status_400_returns_error_test() {
  let req = mock_request("/status/400")
  let assert Error(client.ResponseError(response: client.HttpResponse(
    status: status,
    ..,
  ))) = client.send(req)
  status |> should.equal(400)
}

/// Test: status 401 returns Error
pub fn send_status_401_returns_error_test() {
  let req = mock_request("/status/401")
  let assert Error(client.ResponseError(response: client.HttpResponse(
    status: status,
    ..,
  ))) = client.send(req)
  status |> should.equal(401)
}

/// Test: status 503 returns Error
pub fn send_status_503_returns_error_test() {
  let req = mock_request("/status/503")
  let assert Error(client.ResponseError(response: client.HttpResponse(
    status: status,
    ..,
  ))) = client.send(req)
  status |> should.equal(503)
}

// ============================================================================
// Error Message Quality Tests
// ============================================================================

/// Test: Errors contain useful information
pub fn error_messages_are_informative_test() {
  // Arrange - Connect to non-existent server
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(19_997)
    |> client.path("/nonexistent")

  // Act
  let result = client.send(req)

  // Assert - Error message should have substance
  case result {
    Error(client.RequestError(message: error_msg)) -> {
      // Should be more than just "error" or empty
      string.length(error_msg) |> should.not_equal(0)
      // Should not be just "Nil" or similar
      error_msg |> should.not_equal("Nil")
      error_msg |> should.not_equal("nil")
    }
    Error(client.ResponseError(_)) -> {
      io.println("Expected RequestError, got ResponseError")
      should.fail()
    }
    Ok(_) -> should.fail()
  }
}
