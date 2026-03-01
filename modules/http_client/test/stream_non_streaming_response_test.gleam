//// Regression tests for non-streaming upstream responses during streaming
////
//// When a streaming HTTP request is made via start_stream/stream_yielder and
//// the upstream returns a non-streaming response (e.g. HTTP 401/500 with a
//// JSON body), Erlang's httpc sends a complete response message instead of
//// the expected stream_start/stream/stream_end sequence.
////
//// These tests verify that complete response messages are handled gracefully
//// and surfaced through the existing error paths rather than crashing the
//// stream process or silently hanging.

import dream_http_client/client
import dream_http_client_test
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/list
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

// ============================================================================
// start_stream callback-based path (exercises decode_stream_message_for_selector)
// ============================================================================

/// Streaming to a 401 endpoint must fire on_stream_error, not crash
pub fn start_stream_calls_on_error_for_401_non_streaming_response_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/401")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 3000) {
    Ok(reason) -> {
      string.contains(reason, "401") |> should.be_true()
    }
    Error(Nil) -> {
      io.println("on_stream_error was never called (process likely crashed)")
      should.fail()
    }
  }
}

/// Streaming to a 500 endpoint must fire on_stream_error, not crash
pub fn start_stream_calls_on_error_for_500_non_streaming_response_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/500")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 3000) {
    Ok(reason) -> {
      string.contains(reason, "500") |> should.be_true()
    }
    Error(Nil) -> {
      io.println("on_stream_error was never called (process likely crashed)")
      should.fail()
    }
  }
}

/// Error reason must contain the HTTP status code
pub fn start_stream_error_contains_status_code_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/403")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 3000) {
    Ok(reason) -> {
      string.contains(reason, "403") |> should.be_true()
      string.contains(reason, "HTTP") |> should.be_true()
    }
    Error(Nil) -> {
      io.println("on_stream_error was never called")
      should.fail()
    }
  }
}

/// Error reason must contain the response body from upstream
pub fn start_stream_error_contains_response_body_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/429")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(error_subject, 3000) {
    Ok(reason) -> {
      string.contains(reason, "429") |> should.be_true()
      { string.length(reason) > 10 } |> should.be_true()
    }
    Error(Nil) -> {
      io.println("on_stream_error was never called")
      should.fail()
    }
  }
}

/// Stream process must terminate cleanly, not crash, on non-streaming response
pub fn start_stream_does_not_crash_process_on_non_streaming_response_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/401")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(handle) = client.start_stream(request)

  // Wait for the error callback to fire
  case process.receive(error_subject, 3000) {
    Ok(_reason) -> Nil
    Error(Nil) -> {
      io.println("on_stream_error was never called")
      should.fail()
    }
  }

  // await_stream should return promptly without the caller timing out
  client.await_stream(handle)
  client.is_stream_active(handle) |> should.be_false()
}

// ============================================================================
// stream_yielder pull-based path (exercises stream_owner_wait + stream_owner_next_message)
// ============================================================================

/// Yielder to a 401 endpoint must yield Error containing "401".
/// Uses yielder.take(1) because the yielder retries on start errors (owner
/// never gets set), which would make yielder.to_list loop infinitely.
pub fn stream_yielder_returns_error_for_401_non_streaming_response_test() {
  let req = mock_request("/status/401")
  let results = client.stream_yielder(req) |> yielder.take(1) |> yielder.to_list

  { results != [] } |> should.be_true()

  let assert [first, ..] = results
  case first {
    Error(reason) -> string.contains(reason, "401") |> should.be_true()
    Ok(_) -> {
      io.println("Expected Error, got Ok")
      should.fail()
    }
  }
}

/// Yielder to a 500 endpoint must yield Error containing "500"
pub fn stream_yielder_returns_error_for_500_non_streaming_response_test() {
  let req = mock_request("/status/500")
  let results = client.stream_yielder(req) |> yielder.take(1) |> yielder.to_list

  { results != [] } |> should.be_true()

  let assert [first, ..] = results
  case first {
    Error(reason) -> string.contains(reason, "500") |> should.be_true()
    Ok(_) -> {
      io.println("Expected Error, got Ok")
      should.fail()
    }
  }
}

/// Yielder error must contain the response body text
pub fn stream_yielder_error_contains_response_body_test() {
  let req = mock_request("/status/422")
  let results = client.stream_yielder(req) |> yielder.take(1) |> yielder.to_list

  { results != [] } |> should.be_true()

  let assert [first, ..] = results
  case first {
    Error(reason) -> {
      string.contains(reason, "422") |> should.be_true()
      { string.length(reason) > 10 } |> should.be_true()
    }
    Ok(_) -> {
      io.println("Expected Error, got Ok")
      should.fail()
    }
  }
}

// ============================================================================
// Normal streaming regression guards
// ============================================================================

/// Normal streaming via start_stream still works after the fix
pub fn start_stream_normal_streaming_still_works_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 5000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> {
      io.println("on_stream_end was never called")
      should.fail()
    }
  }

  let chunks = collect_from_subject(chunks_subject, [])
  { chunks != [] } |> should.be_true()
}

/// Normal streaming via stream_yielder still works after the fix
pub fn stream_yielder_normal_streaming_still_works_test() {
  let req = mock_request("/stream/fast")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let all_ok =
    list.all(results, fn(result) {
      case result {
        Ok(_) -> True
        Error(reason) -> {
          io.println("Unexpected error in normal stream: " <> reason)
          False
        }
      }
    })
  all_ok |> should.be_true()
}

fn collect_from_subject(subject: process.Subject(a), acc: List(a)) -> List(a) {
  case process.receive(subject, 50) {
    Ok(item) -> collect_from_subject(subject, [item, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
