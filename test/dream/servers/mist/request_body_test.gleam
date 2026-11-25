//// Tests for how a request body arrives at a controller.
////
//// Starts a real dream server on a free port, sends raw HTTP/1.1 bytes,
//// and reads back what the controller saw. The controller answers with a
//// tag for the body shape, then the exact body bytes, so a test can see
//// both the shape and the bytes in one value.

import dream/http/request.{
  type BodyReadError, type Request, Bytes, Post, Stream, Text,
}
import dream/http/response.{type Response, binary_response}
import dream/router.{route, router, stream_route}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/bit_array
import gleam/int
import gleam/result
import gleam/string
import gleam/yielder

const socket_timeout_ms = 2000

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("request body", [
    it("delivers a body that is not valid UTF-8 as Bytes", fn() {
      // Arrange
      let body = <<0xFF, 0xD8, 0xFF, 0x00>>

      // Act
      let result = post_and_read_body("/buffered", body)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal(<<"Bytes:":utf8, 0xFF, 0xD8, 0xFF, 0x00>>)
      |> or_fail_with("Controller should receive Bytes with the exact bytes")
    }),
    it("delivers a UTF-8 body as Text", fn() {
      // Arrange
      let body = <<"héllo":utf8>>

      // Act
      let result = post_and_read_body("/buffered", body)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal(<<"Text:héllo":utf8>>)
      |> or_fail_with("Controller should receive Text with the same text")
    }),
    it("delivers an empty body as empty Text", fn() {
      // Arrange
      let body = <<>>

      // Act
      let result = post_and_read_body("/buffered", body)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal(<<"Text:":utf8>>)
      |> or_fail_with("Controller should receive Text(\"\")")
    }),
    it("delivers a stream_route body as Stream with every byte", fn() {
      // Arrange
      let body = <<0xFF, 0xD8, "chunked":utf8, 0x00>>

      // Act
      let result = post_and_read_body("/streaming", body)

      // Assert
      result
      |> should()
      |> be_ok()
      |> be_equal(<<"Stream:":utf8, 0xFF, 0xD8, "chunked":utf8, 0x00>>)
      |> or_fail_with("Controller should receive a Stream of the sent bytes")
    }),
  ])
}

// ============================================================================
// Controller and router
// ============================================================================

fn echo_body_controller(request: Request, _context, _services) -> Response {
  binary_response(200, describe_body(request), "application/octet-stream")
}

fn describe_body(request: Request) -> BitArray {
  case request.body {
    Text(text) -> <<"Text:":utf8, text:utf8>>
    Bytes(bytes) -> <<"Bytes:":utf8, bytes:bits>>
    Stream(chunks) ->
      chunks
      |> yielder.try_fold(<<"Stream:":utf8>>, append_item)
      |> result.unwrap(<<"Broken stream":utf8>>)
  }
}

fn append_item(
  body: BitArray,
  item: Result(BitArray, BodyReadError),
) -> Result(BitArray, BodyReadError) {
  result.map(item, bit_array.append(body, _))
}

fn echo_router() {
  router()
  |> route(
    method: Post,
    path: "/buffered",
    controller: echo_body_controller,
    middleware: [],
  )
  |> stream_route(
    method: Post,
    path: "/streaming",
    controller: echo_body_controller,
    middleware: [],
  )
}

// ============================================================================
// Helpers
// ============================================================================

/// Starts a server on a free port, posts `body` to `path`, stops the server
/// and returns the response body bytes.
fn post_and_read_body(
  path: String,
  body: BitArray,
) -> Result(BitArray, String) {
  let port = free_port()
  use handle <- result.try(start_server(port))
  let received = send_post(port, path, body)
  server.stop(handle)
  received
}

fn start_server(port: Int) -> Result(server.ServerHandle, String) {
  let started =
    server.new()
    |> server.router(echo_router())
    |> server.listen_with_handle(port)

  case started {
    Ok(handle) -> Ok(handle)
    Error(start_error) ->
      Error(
        "Failed to start server on port "
        <> int.to_string(port)
        <> ": "
        <> string.inspect(start_error),
      )
  }
}

fn send_post(
  port: Int,
  path: String,
  body: BitArray,
) -> Result(BitArray, String) {
  let head =
    "POST "
    <> path
    <> " HTTP/1.1\r\n"
    <> "host: 127.0.0.1\r\n"
    <> "content-length: "
    <> int.to_string(bit_array.byte_size(body))
    <> "\r\n\r\n"
  let payload = bit_array.append(bit_array.from_string(head), body)

  exchange(port, payload, socket_timeout_ms)
}

/// Sends one request and returns the body of the response as soon as it is
/// complete (content-length or chunked framing), without waiting for the
/// server to close the connection.
@external(erlang, "raw_http_ffi", "exchange")
fn exchange(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, String)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
