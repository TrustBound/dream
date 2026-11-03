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
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

const test_port = 19_970

/// How many requests to send in one test. The failure this guards against
/// is a race, so one request is not enough to make it show.
const attempts = 50

const socket_timeout_ms = 2000

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("chunked stream", [
    it(
      "sends exactly one response when the request body is already buffered",
      fn() {
        use handle <- with_echo_server(test_port)

        let failures =
          int.range(from: 1, to: attempts + 1, with: [], run: record_failure)
          |> list.reverse

        server.stop(handle)

        case failures {
          [] -> AssertionOk
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
fn record_failure(failures: List(String), attempt: Int) -> List(String) {
  case check_single_response(send_echo_request(test_port)) {
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
  case request.stream {
    Some(stream) -> stream_response(200, stream, "text/plain")
    None -> text_response(400, "Expected streaming request body")
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
  test_fn: fn(server.ServerHandle) -> AssertionResult,
) -> AssertionResult {
  let result =
    server.new()
    |> server.router(echo_router())
    |> server.listen_with_handle(port)

  case result {
    Ok(handle) -> {
      process.sleep(100)
      test_fn(handle)
    }
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

fn assertion_failed(operator: String, message: String) -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: operator,
    message: message,
    payload: None,
  ))
}

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, Dynamic)
