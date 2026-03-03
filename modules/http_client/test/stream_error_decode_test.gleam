//// Tests for stream error reason decoding robustness
////
//// Verifies that the HTTP client can decode error reasons from Erlang's httpc
//// regardless of the error format: transport-level errors (atoms/tuples from
//// httpc), non-UTF-8 response bodies, and connection failures. Both the
//// message-based (start_stream) and pull-based (stream_yielder) paths are
//// tested.
////
//// These tests close the gap left by stream_non_streaming_response_test.gleam,
//// which only covered HTTP error responses (complete response messages). The
//// tests here cover the {error, Reason} message path from httpc, which fires
//// on transport-level failures like connection refused and socket drops.

import dream_http_client/client
import dream_http_client_test
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/string
import gleam/yielder
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

fn dead_port_request() -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(1)
  |> client.path("/anything")
  |> client.timeout(3000)
}

// ============================================================================
// Connection refused tests (httpc {error, Reason} path with atom/tuple reason)
// ============================================================================

/// start_stream to a closed port must fire on_stream_error with a readable string
pub fn start_stream_connection_refused_surfaces_error_test() {
  let error_subject = process.new_subject()

  let request =
    dead_port_request()
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let _result = client.start_stream(request)

  case process.receive(error_subject, 10_000) {
    Ok(reason) -> {
      { string.length(reason) > 0 } |> should.be_true()
      io.println(
        "start_stream connection refused error: " <> string.slice(reason, 0, 80),
      )
    }
    Error(Nil) -> {
      io.println(
        "on_stream_error was never called for connection refused (start_stream)",
      )
      should.fail()
    }
  }
}

/// stream_yielder to a closed port must yield Error with a readable string
pub fn stream_yielder_connection_refused_surfaces_error_test() {
  let req = dead_port_request()
  let results = client.stream_yielder(req) |> yielder.take(1) |> yielder.to_list

  { results != [] } |> should.be_true()

  let assert [first, ..] = results
  case first {
    Error(reason) -> {
      { string.length(reason) > 0 } |> should.be_true()
      io.println(
        "stream_yielder connection refused error: "
        <> string.slice(reason, 0, 80),
      )
    }
    Ok(_) -> {
      io.println("Expected Error for connection refused, got Ok")
      should.fail()
    }
  }
}

/// send() to a closed port must return RequestError with a readable string
pub fn send_connection_refused_surfaces_error_test() {
  let req = dead_port_request()
  case client.send(req) {
    Error(client.RequestError(message: reason)) -> {
      { string.length(reason) > 0 } |> should.be_true()
      io.println(
        "send() connection refused error: " <> string.slice(reason, 0, 80),
      )
    }
    Error(client.ResponseError(response: _)) -> {
      io.println("Expected RequestError, got ResponseError")
      should.fail()
    }
    Ok(_) -> {
      io.println("Expected Error for connection refused, got Ok")
      should.fail()
    }
  }
}

// ============================================================================
// Connection drop mid-stream tests (socket_closed_remotely)
// ============================================================================

/// start_stream to /stream/drop must fire on_stream_error, not crash
pub fn start_stream_connection_drop_surfaces_error_test() {
  let error_subject = process.new_subject()
  let chunk_subject = process.new_subject()

  let request =
    mock_request("/stream/drop")
    |> client.on_stream_chunk(fn(data) { process.send(chunk_subject, data) })
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 10_000) {
    Ok(reason) -> {
      { string.length(reason) > 0 } |> should.be_true()
      io.println("start_stream drop error: " <> string.slice(reason, 0, 80))
    }
    Error(Nil) -> {
      io.println(
        "on_stream_error was never called for connection drop (start_stream)",
      )
      should.fail()
    }
  }
}

/// stream_yielder to /stream/drop must eventually yield Error
pub fn stream_yielder_connection_drop_surfaces_error_test() {
  let req = mock_request("/stream/drop")
  let results =
    client.stream_yielder(req) |> yielder.take(10) |> yielder.to_list

  let has_error =
    results
    |> yielder.from_list
    |> yielder.any(fn(r) {
      case r {
        Error(_) -> True
        Ok(_) -> False
      }
    })

  has_error |> should.be_true()
}

// ============================================================================
// Non-UTF-8 response body tests
// ============================================================================

/// start_stream to /non-utf8-error must fire on_stream_error with decodable reason
pub fn start_stream_non_utf8_error_body_surfaces_error_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/non-utf8-error")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 5000) {
    Ok(reason) -> {
      { string.length(reason) > 0 } |> should.be_true()
      string.contains(reason, "400") |> should.be_true()
      io.println(
        "start_stream non-UTF-8 error: " <> string.slice(reason, 0, 80),
      )
    }
    Error(Nil) -> {
      io.println(
        "on_stream_error was never called for non-UTF-8 error body (start_stream)",
      )
      should.fail()
    }
  }
}

/// stream_yielder to /non-utf8-error must yield Error with readable reason
pub fn stream_yielder_non_utf8_error_body_surfaces_error_test() {
  let req = mock_request("/non-utf8-error")
  let results = client.stream_yielder(req) |> yielder.take(1) |> yielder.to_list

  { results != [] } |> should.be_true()

  let assert [first, ..] = results
  case first {
    Error(reason) -> {
      { string.length(reason) > 0 } |> should.be_true()
      string.contains(reason, "400") |> should.be_true()
      io.println(
        "stream_yielder non-UTF-8 error: " <> string.slice(reason, 0, 80),
      )
    }
    Ok(_) -> {
      io.println("Expected Error for non-UTF-8 error body, got Ok")
      should.fail()
    }
  }
}

/// send() to /non-utf8-error must return an Error (not crash).
/// Since HttpResponse.body is typed as String, non-UTF-8 bytes cause a
/// RequestError("Failed to convert response to string") which is correct —
/// the body can't be represented as a Gleam String.
pub fn send_non_utf8_error_body_surfaces_error_test() {
  let req = mock_request("/non-utf8-error")
  case client.send(req) {
    Error(client.RequestError(message: msg)) -> {
      { string.length(msg) > 0 } |> should.be_true()
      io.println("send() non-UTF-8 body error (expected): " <> msg)
    }
    Error(client.ResponseError(response: _resp)) -> {
      // Also acceptable if the body was lossy-decoded
      Nil
    }
    Ok(_) -> {
      io.println("Expected Error for non-UTF-8 error body, got Ok")
      should.fail()
    }
  }
}

// ============================================================================
// Error string quality tests
// ============================================================================

/// Connection refused errors must contain useful diagnostic info, not just
/// "Unknown stream error" or a raw Erlang term dump
pub fn connection_refused_error_is_not_unknown_test() {
  let error_subject = process.new_subject()

  let request =
    dead_port_request()
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let _result = client.start_stream(request)

  case process.receive(error_subject, 10_000) {
    Ok(reason) -> {
      string.contains(reason, "Unknown stream error") |> should.be_false()
    }
    Error(Nil) -> {
      io.println("on_stream_error was never called")
      should.fail()
    }
  }
}
