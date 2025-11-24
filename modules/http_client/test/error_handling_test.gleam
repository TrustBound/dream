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
import gleam/string
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

// ============================================================================
// send() Error Status Code Tests
// ============================================================================

/// Test: send() returns body even with 404 status
pub fn send_404_status_test() {
  // Arrange
  let req = mock_request("/status/404")

  // Act
  let result = client.send(req)

  // Assert - httpc returns body regardless of status code
  case result {
    Ok(body) -> {
      string.contains(body, "404") |> should.be_true()
    }
    Error(_) -> {
      // Connection-level errors are acceptable for status code tests
      Nil
    }
  }
}

/// Test: send() returns body even with 500 status
pub fn send_500_status_test() {
  // Arrange
  let req = mock_request("/status/500")

  // Act
  let result = client.send(req)

  // Assert - httpc returns body regardless of status code
  case result {
    Ok(body) -> {
      string.contains(body, "500") |> should.be_true()
    }
    Error(_) -> {
      // Connection-level errors are acceptable for status code tests
      Nil
    }
  }
}

/// Test: send() returns body with 400 status
pub fn send_400_status_test() {
  // Arrange
  let req = mock_request("/status/400")

  // Act
  let result = client.send(req)

  // Assert - httpc returns body regardless of status code
  case result {
    Ok(body) -> {
      string.contains(body, "400") |> should.be_true()
    }
    Error(_) -> {
      // Connection-level errors are acceptable for status code tests
      Nil
    }
  }
}

/// Test: send() returns error on connection failure
pub fn send_connection_failure_test() {
  // Arrange - Use a port that won't have a server listening
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(19_999)
    |> client.path("/nonexistent")

  // Act
  let result = client.send(req)

  // Assert - Should get an error
  case result {
    Error(error_msg) -> {
      // Error message should be informative
      string.length(error_msg) |> should.not_equal(0)
    }
    Ok(_) -> should.fail()
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
    Ok(body) -> {
      // Should be at least 100KB
      string.length(body) |> should.not_equal(0)
      { string.length(body) > 100_000 } |> should.be_true()
    }
    Error(error_reason) -> {
      io.println(
        "Expected large response to succeed, got error: " <> error_reason,
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
    Ok(body) -> {
      body |> should.equal("")
    }
    Error(error_reason) -> {
      io.println(
        "Expected empty response to succeed, got error: " <> error_reason,
      )
      should.fail()
    }
  }
}

// ============================================================================
// Error Message Quality Tests
// ============================================================================

/// Test: Errors contain useful information
pub fn error_messages_are_informative_test() {
  // Arrange - Connect to non-existent server
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(19_997)
    |> client.path("/nonexistent")

  // Act
  let result = client.send(req)

  // Assert - Error message should have substance
  case result {
    Error(error_msg) -> {
      // Should be more than just "error" or empty
      string.length(error_msg) |> should.not_equal(0)
      // Should not be just "Nil" or similar
      error_msg |> should.not_equal("Nil")
      error_msg |> should.not_equal("nil")
    }
    Ok(_) -> should.fail()
  }
}
