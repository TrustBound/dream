//// Tests for chunked streaming responses over HTTP/1.1 at the socket level.
////
//// Starts a real dream server with a streaming route that echoes the request
//// body, sends the request headers and body in one TCP packet, and reads
//// every byte the server writes until it closes the connection. A normal
//// HTTP client stops reading at the end of the chunked body, so it cannot
//// see a second response that the server appends by mistake.

import dream/http/request.{type Request, Post}
import dream/http/response.{type Response, stream_response, text_response}
import dream/router.{router, stream_route}
import dream/servers/mist/server
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import dream_test/unit.{describe, it}
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import gleam/yielder

/// How many requests to send in one test. The failure this guards against
/// is a race, so one request is not enough to make it show.
const attempts = 50

/// The server keeps the connection open after the last chunk, so each read
/// ends when no data came for this time.
const socket_timeout_ms = 50

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("chunked stream", [
    it(
      "sends exactly one response when the request body is already buffered",
      fn() {
        let port = free_port()
        use handle <- with_echo_server(port)

        let failures =
          int.range(
            from: 1,
            to: attempts + 1,
            with: [],
            run: fn(failures, attempt) {
              record_failure(failures, attempt, port)
            },
          )
          |> list.reverse

        server.stop(handle)

        case failures {
          [] -> Ok(AssertionOk)
          [first, ..] ->
            assertion_failed(
              "chunked_single_response",
              int.to_string(list.length(failures))
                <> " of "
                <> int.to_string(attempts)
                <> " requests failed, first: "
                <> first,
            )
        }
      },
    ),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

/// Sends a POST whose headers and 5-byte body share one packet, so the
/// stream can be drained without touching the socket again.
fn send_echo_request(port: Int) -> Result(BitArray, Dynamic) {
  let payload =
    "POST /echo HTTP/1.1\r\n"
    <> "host: 127.0.0.1\r\n"
    <> "content-length: 5\r\n"
    <> "\r\n"
    <> "hello"

  request_until_closed(port, bit_array.from_string(payload), socket_timeout_ms)
}

/// Sends one echo request and keeps a message for it when it fails.
fn record_failure(
  failures: List(String),
  attempt: Int,
  port: Int,
) -> List(String) {
  case check_single_response(send_echo_request(port)) {
    Ok(Nil) -> failures
    Error(message) -> [
      "attempt " <> int.to_string(attempt) <> ": " <> message,
      ..failures
    ]
  }
}

fn check_single_response(
  received: Result(BitArray, Dynamic),
) -> Result(Nil, String) {
  case received {
    Error(reason) -> Error("socket error: " <> string.inspect(reason))
    Ok(bytes) ->
      case bit_array.to_string(bytes) {
        Error(Nil) -> Error("server wrote non UTF-8 bytes")
        Ok(text) -> check_response_text(text)
      }
  }
}

fn check_response_text(text: String) -> Result(Nil, String) {
  let status_lines = count_occurrences(text, "HTTP/1.1 ")
  let starts_with_200 = string.starts_with(text, "HTTP/1.1 200")
  let has_echoed_chunk = string.contains(text, "5\r\nhello\r\n0\r\n\r\n")

  case starts_with_200, has_echoed_chunk, status_lines {
    True, True, 1 -> Ok(Nil)
    _, _, _ ->
      Error(
        "expected one 200 response echoing 'hello', got "
        <> int.to_string(status_lines)
        <> " status line(s): "
        <> string.inspect(text),
      )
  }
}

fn count_occurrences(haystack: String, needle: String) -> Int {
  list.length(string.split(haystack, needle)) - 1
}

fn echo_stream_controller(request: Request, _context, _services) -> Response {
  case request.body {
    // The test client sends the whole body, so no item is an Error
    request.Stream(chunks) ->
      stream_response(
        200,
        yielder.filter_map(chunks, function.identity),
        "text/plain",
      )
    request.Text(_text) -> text_response(400, "Expected streaming request body")
    request.Bytes(_bytes) ->
      text_response(400, "Expected streaming request body")
  }
}

fn echo_router() {
  router()
  |> stream_route(
    method: Post,
    path: "/echo",
    controller: echo_stream_controller,
    middleware: [],
  )
}

fn with_echo_server(
  port: Int,
  test_fn: fn(server.ServerHandle) -> Result(AssertionResult, String),
) -> Result(AssertionResult, String) {
  let result =
    server.new()
    |> server.router(echo_router())
    |> server.listen_with_handle(port)

  case result {
    Ok(handle) -> test_fn(handle)
    Error(start_error) ->
      assertion_failed(
        "with_echo_server",
        "Failed to start server on port "
          <> int.to_string(port)
          <> ": "
          <> string.inspect(start_error),
      )
  }
}

fn assertion_failed(
  operator: String,
  message: String,
) -> Result(AssertionResult, String) {
  Ok(
    AssertionFailed(AssertionFailure(
      operator: operator,
      message: message,
      payload: None,
    )),
  )
}

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, Dynamic)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
