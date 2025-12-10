//// Tests for start_stream() callback-based API

import dream_http_client/client
import dream_http_client_test
import gleam/erlang/process
import gleam/http
import gleam/list
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

pub fn start_stream_returns_handle_test() {
  // Arrange
  let request = mock_request("/stream/fast")

  // Act
  let result = client.start_stream(request)

  // Assert
  result |> should.be_ok()

  case result {
    Ok(handle) -> client.cancel_stream_handle(handle)
    Error(_) -> Nil
  }
}

pub fn start_stream_calls_on_chunk_callback_test() {
  // Arrange
  let chunks_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })

  // Act
  let assert Ok(_handle) = client.start_stream(request)

  // Wait for chunks
  process.sleep(1000)

  // Assert - received at least one chunk
  let chunks = collect_from_subject(chunks_subject, [])
  { chunks != [] } |> should.be_true()
}

pub fn start_stream_calls_on_start_callback_test() {
  // Arrange
  let started_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.on_stream_start(fn(_headers) {
      process.send(started_subject, True)
    })

  // Act
  let assert Ok(_handle) = client.start_stream(request)

  // Assert - on_start was called
  case process.receive(started_subject, 1000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

pub fn start_stream_calls_on_end_callback_test() {
  // Arrange
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  // Act
  let assert Ok(_handle) = client.start_stream(request)

  // Assert - on_end was called
  case process.receive(ended_subject, 3000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

pub fn start_stream_calls_on_error_for_network_failure_test() {
  // Arrange - invalid port
  let error_subject = process.new_subject()

  let request =
    client.new
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(19_999)
    |> client.path("/")
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  // Act
  let assert Ok(_handle) = client.start_stream(request)

  // Assert - on_error was called
  case process.receive(error_subject, 2000) {
    Ok(reason) -> {
      { reason != "" } |> should.be_true()
    }
    Error(Nil) -> should.fail()
  }
}

pub fn await_stream_waits_for_completion_test() {
  // Arrange
  let request = mock_request("/stream/fast")

  // Act
  let assert Ok(handle) = client.start_stream(request)
  client.await_stream(handle)

  // Assert - process should be dead now
  client.is_stream_active(handle) |> should.be_false()
}

pub fn cancel_stream_handle_stops_stream_test() {
  // Arrange
  let request = mock_request("/stream/slow")
  let assert Ok(handle) = client.start_stream(request)

  // Act - Cancel immediately
  client.cancel_stream_handle(handle)
  process.sleep(100)

  // Assert - process is dead
  client.is_stream_active(handle) |> should.be_false()
}

pub fn is_stream_active_returns_true_while_running_test() {
  // Arrange
  let request = mock_request("/stream/slow")
  let assert Ok(handle) = client.start_stream(request)

  // Act/Assert - immediately after start, should be alive
  client.is_stream_active(handle) |> should.be_true()

  // Cleanup
  client.cancel_stream_handle(handle)
}

fn collect_from_subject(subject: process.Subject(a), acc: List(a)) -> List(a) {
  case process.receive(subject, 50) {
    Ok(item) -> collect_from_subject(subject, [item, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
