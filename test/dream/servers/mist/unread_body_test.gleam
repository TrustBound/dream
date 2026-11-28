//// Tests that a request body that Dream did not read is never answered as
//// a request.
////
//// A client sends a request whose body is the text of a second request.
//// When the server answers without reading that body, and then reads the
//// next request from the same connection, it answers the hidden request.
//// Each test starts a real dream server on a free port, sends the first
//// request, reads its answer, then sends the hidden request on the same
//// connection. The server must give exactly one answer and close the
//// connection. The last test is the control: a body that the controller
//// reads in full, then a real second request, gets two answers.

import dream/http/request.{type Request, Get, Post}
import dream/http/response.{type Response, text_response}
import dream/router.{route, router, stream_route}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string

const socket_timeout_ms = 1000

const max_body_size = 1000

/// The request that hides in the body of the first request
const hidden_request = "GET / HTTP/1.1\r\nhost: localhost\r\n\r\n"

pub fn tests() -> TestSuite {
  describe("a body that the server did not read", [
    it("is not answered after a 404 for a path with no route", fn() {
      // Arrange
      let first = head_with_hidden_body("POST", "/no-such-route")

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 404 Not Found"], "closed"))
      |> or_fail_with("only the 404 should come back, then the server closes")
    }),
    it("is not answered after a 413 for a content-length over the limit", fn() {
      // Arrange
      let first =
        "POST /echo HTTP/1.1\r\nhost: localhost\r\ncontent-length: 2000000\r\n\r\n"

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 413 Payload Too Large"], "closed"))
      |> or_fail_with("only the 413 should come back, then the server closes")
    }),
    it("is not answered after a 413 for a chunked body over the limit", fn() {
      // Arrange
      let chunk = "1f4\r\n" <> string.repeat("a", 500) <> "\r\n"
      let first =
        "POST /echo HTTP/1.1\r\nhost: localhost\r\ntransfer-encoding: chunked\r\n\r\n"
        <> string.repeat(chunk, 3)

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 413 Payload Too Large"], "closed"))
      |> or_fail_with("only the 413 should come back, then the server closes")
    }),
    it("is not answered after a controller that does not read the body", fn() {
      // Arrange
      let first = head_with_hidden_body("POST", "/ignores-body")

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 200 OK"], "closed"))
      |> or_fail_with("only the 200 should come back, then the server closes")
    }),
    it("is not answered after a 405 for a GET route sent a POST", fn() {
      // Arrange
      let first = head_with_hidden_body("POST", "/")

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 405 Method Not Allowed"], "closed"))
      |> or_fail_with("only the 405 should come back, then the server closes")
    }),
    it("answers a real second request after a body that was read", fn() {
      // Arrange
      let first =
        "POST /echo HTTP/1.1\r\nhost: localhost\r\ncontent-length: 5\r\n\r\nhello"

      // Act
      let result = send_then_hide(first)

      // Assert
      result
      |> should
      |> be_ok()
      |> be_equal(#(["HTTP/1.1 200 OK", "HTTP/1.1 200 OK"], "open"))
      |> or_fail_with(
        "both requests should get an answer on an open connection",
      )
    }),
  ])
}

// ============================================================================
// Controllers and router
// ============================================================================

fn index(_request: Request, _context, _services) -> Response {
  text_response(200, "Hello, World!")
}

fn echo_body(request: Request, _context, _services) -> Response {
  case request.body_as_string(request) {
    Ok(text) -> text_response(200, text)
    Error(Nil) -> text_response(400, "not text")
  }
}

fn ignore_body(_request: Request, _context, _services) -> Response {
  text_response(200, "ignored")
}

fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
  |> route(method: Post, path: "/echo", controller: echo_body, middleware: [])
  |> stream_route(
    method: Post,
    path: "/ignores-body",
    controller: ignore_body,
    middleware: [],
  )
}

// ============================================================================
// Helpers
// ============================================================================

/// The head of a request whose body is the hidden request
fn head_with_hidden_body(method: String, path: String) -> String {
  method
  <> " "
  <> path
  <> " HTTP/1.1\r\nhost: localhost\r\ncontent-length: "
  <> int.to_string(string.byte_size(hidden_request))
  <> "\r\n\r\n"
}

/// Starts a server on a free port, sends `first`, reads its answer, sends
/// the hidden request on the same connection, and stops the server. Returns
/// the status line of each answer, and how the connection ended.
fn send_then_hide(first: String) -> Result(#(List(String), String), String) {
  let port = free_port()
  use handle <- result.try(start_server(port))
  let received =
    send_after_response(
      port,
      bit_array.from_string(first),
      bit_array.from_string(hidden_request),
      socket_timeout_ms,
    )
  server.stop(handle)
  result.map(received, describe_exchange)
}

fn describe_exchange(received: #(BitArray, String)) -> #(List(String), String) {
  let #(bytes, end) = received
  #(status_lines(bytes), end)
}

/// The status line of each answer. An answer can follow the body of the
/// answer before it with no line break, so each status line starts at
/// "HTTP/1.1 " and ends at the first line break after it.
fn status_lines(bytes: BitArray) -> List(String) {
  bit_array.to_string(bytes)
  |> result.unwrap("")
  |> string.split("HTTP/1.1 ")
  |> list.drop(1)
  |> list.map(status_line)
}

fn status_line(after_version: String) -> String {
  case string.split_once(after_version, "\r\n") {
    Ok(#(status, _rest)) -> "HTTP/1.1 " <> status
    Error(Nil) -> "HTTP/1.1 " <> after_version
  }
}

fn start_server(port: Int) -> Result(server.ServerHandle, String) {
  server.new()
  |> server.router(app_router())
  |> server.max_body_size(max_body_size)
  |> server.listen_with_handle(port)
  |> result.map_error(fn(start_error) {
    "Failed to start server on port "
    <> int.to_string(port)
    <> ": "
    <> string.inspect(start_error)
  })
}

@external(erlang, "raw_http_ffi", "send_after_response")
fn send_after_response(
  port: Int,
  first: BitArray,
  second: BitArray,
  timeout_ms: Int,
) -> Result(#(BitArray, String), String)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
