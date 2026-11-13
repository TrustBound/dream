//// Black-box tests for `dream_opensearch/client`.
////
//// Requests go to a one-shot server on 127.0.0.1 (see `test_server`), which
//// records the request line, headers and body exactly as they arrive.

import dream_opensearch/client.{Client}
import gleam/bit_array
import gleam/http
import gleam/string
import gleeunit/should
import opensearch_test_server.{CaptureRawBytes, Respond}

// ============================================================================
// new
// ============================================================================

pub fn new_without_trailing_slash_keeps_url_test() {
  // Arrange
  let base_url = "http://localhost:9200"

  // Act
  let result = client.new(base_url)

  // Assert
  result |> should.equal(Client(base_url: "http://localhost:9200"))
}

pub fn new_with_trailing_slash_removes_it_test() {
  // Arrange
  let base_url = "http://localhost:9200/"

  // Act
  let result = client.new(base_url)

  // Assert
  result |> should.equal(Client(base_url: "http://localhost:9200"))
}

pub fn new_with_path_prefix_and_trailing_slash_keeps_prefix_test() {
  // Arrange
  let base_url = "https://search.example.com:9200/opensearch/"

  // Act
  let result = client.new(base_url)

  // Assert
  result
  |> should.equal(Client(base_url: "https://search.example.com:9200/opensearch"))
}

pub fn new_with_empty_string_returns_empty_base_url_test() {
  // Arrange
  let base_url = ""

  // Act
  let result = client.new(base_url)

  // Assert
  result |> should.equal(Client(base_url: ""))
}

// ============================================================================
// send_request: the request it builds
// ============================================================================

pub fn send_request_sends_given_method_and_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = client.send_request(os_client, http.Get, "/users/_doc/123", "")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("GET", "/users/_doc/123"))
}

pub fn send_request_sends_patch_method_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = client.send_request(os_client, http.Patch, "/users/_doc/1", "{}")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("PATCH", "/users/_doc/1"))
}

pub fn send_request_sends_one_json_content_type_header_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = client.send_request(os_client, http.Post, "/users/_search", "{}")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.header_values("content-type")
  |> should.equal(["application/json"])
}

pub fn send_request_sends_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))
  let body = "{\"name\":\"O'Brien \\\"Al\\\" \\\\ zoë 日本\",\n\"x\":1}"

  // Act
  let _ = client.send_request(os_client, http.Put, "/users/_doc/1", body)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal("{\"name\":\"O'Brien \\\"Al\\\" \\\\ zoë 日本\",\n\"x\":1}")
}

pub fn send_request_with_empty_body_sends_empty_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = client.send_request(os_client, http.Delete, "/users", "")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("")
}

pub fn send_request_sends_one_megabyte_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))
  let body = string.repeat("a", 1_048_576)

  // Act
  let _ = client.send_request(os_client, http.Post, "/_bulk", body)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal(string.repeat("a", 1_048_576))
}

pub fn send_request_with_trailing_slash_base_url_sends_single_slash_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server) <> "/")

  // Act
  let _ = client.send_request(os_client, http.Get, "/users/_search", "")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("GET", "/users/_search"))
}

pub fn send_request_with_base_url_path_prefix_prepends_prefix_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client =
    client.new(opensearch_test_server.base_url(server) <> "/opensearch")

  // Act
  let _ = client.send_request(os_client, http.Get, "/users/_search", "")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("GET", "/opensearch/users/_search"))
}

pub fn send_request_with_empty_path_requests_root_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = client.send_request(os_client, http.Get, "", "")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("GET", "/"))
}

pub fn send_request_with_https_base_url_starts_tls_handshake_test() {
  // Arrange
  let server = opensearch_test_server.start(CaptureRawBytes)
  let os_client =
    client.new(
      "https://127.0.0.1:"
      <> string.inspect(opensearch_test_server.port(server)),
    )

  // Act
  let _ = client.send_request(os_client, http.Get, "/", "")

  // Assert: 22 (0x16) is the TLS handshake record type of a ClientHello
  opensearch_test_server.await_raw_bytes(server)
  |> should.be_ok
  |> bit_array.slice(0, 1)
  |> should.equal(Ok(<<22>>))
}

// ============================================================================
// send_request: how it maps responses and failures
// ============================================================================

pub fn send_request_with_200_returns_ok_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "{\"acknowledged\":true}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Ok("{\"acknowledged\":true}"))
}

pub fn send_request_with_201_returns_ok_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(201, "{\"result\":\"created\"}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Put, "/users/_doc/1", "{}")

  // Assert
  result |> should.equal(Ok("{\"result\":\"created\"}"))
}

pub fn send_request_with_204_and_empty_body_returns_ok_empty_string_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(204, ""))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Ok(""))
}

pub fn send_request_with_200_non_json_body_returns_ok_body_unchanged_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "plain text, not JSON"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Ok("plain text, not JSON"))
}

pub fn send_request_with_200_unicode_body_returns_ok_body_unchanged_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "{\"name\":\"zoë 日本 🎉\"}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Ok("{\"name\":\"zoë 日本 🎉\"}"))
}

pub fn send_request_with_399_returns_ok_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(399, "edge"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Ok("edge"))
}

pub fn send_request_with_400_returns_error_body_test() {
  // Arrange
  let body = "{\"error\":{\"type\":\"parsing_exception\"},\"status\":400}"
  let server = opensearch_test_server.start(Respond(400, body))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Post, "/u/_search", "{")

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"parsing_exception\"},\"status\":400}",
  ))
}

pub fn send_request_with_404_returns_error_body_test() {
  // Arrange
  let body = "{\"_index\":\"users\",\"_id\":\"9\",\"found\":false}"
  let server = opensearch_test_server.start(Respond(404, body))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/users/_doc/9", "")

  // Assert
  result
  |> should.equal(Error("{\"_index\":\"users\",\"_id\":\"9\",\"found\":false}"))
}

pub fn send_request_with_500_returns_error_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(500, "{\"status\":500}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Error("{\"status\":500}"))
}

pub fn send_request_with_503_non_json_body_returns_error_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(503, "Service Unavailable"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Error("Service Unavailable"))
}

pub fn send_request_with_error_status_and_empty_body_returns_error_empty_string_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(502, ""))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Error(""))
}

pub fn send_request_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result = client.send_request(os_client, http.Get, "/", "")

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}
