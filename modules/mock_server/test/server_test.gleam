//// Unit tests for mock server port configuration and lifecycle

import dream_mock_server/server
import gleam/erlang/process
import gleam/int
import gleeunit/should

/// Test: Server starts successfully on specified port
pub fn start_on_specific_port_test() {
  let port = 19_876

  let result = server.start(port)

  case result {
    Ok(handle) -> {
      process.sleep(200)
      server.stop(handle)
      process.sleep(500)
    }
    Error(_start_error) -> Nil
  }

  should.be_ok(result)
}

/// Test: Server responds to requests on specified port
pub fn server_responds_on_correct_port_test() {
  let port = 19_877

  let assert Ok(handle) = server.start(port)
  process.sleep(200)

  let url = "http://localhost:" <> int.to_string(port) <> "/text"
  let response_result = make_http_request(url)

  server.stop(handle)
  process.sleep(500)

  should.be_ok(response_result)
}

/// Test: Server can be stopped and does not respond after stopping
pub fn stop_server_test() {
  let port = 19_878

  let assert Ok(handle) = server.start(port)
  process.sleep(200)

  server.stop(handle)
  process.sleep(500)

  let url = "http://localhost:" <> int.to_string(port) <> "/text"
  let response_result = make_http_request(url)

  should.be_error(response_result)
}

/// Test: Multiple servers can run on different ports simultaneously
pub fn multiple_servers_on_different_ports_test() {
  let port1 = 19_880
  let port2 = 19_881

  let assert Ok(handle1) = server.start(port1)
  let assert Ok(handle2) = server.start(port2)
  process.sleep(200)

  let url1 = "http://localhost:" <> int.to_string(port1) <> "/text"
  let url2 = "http://localhost:" <> int.to_string(port2) <> "/text"

  let response1 = make_http_request(url1)
  let response2 = make_http_request(url2)

  server.stop(handle1)
  server.stop(handle2)
  process.sleep(500)

  should.be_ok(response1)
  should.be_ok(response2)
}

/// Test: Server can be restarted on same port after stopping
pub fn restart_on_same_port_test() {
  let port = 19_882

  let assert Ok(handle1) = server.start(port)
  process.sleep(200)
  server.stop(handle1)
  process.sleep(500)

  let result2 = server.start(port)

  case result2 {
    Ok(handle2) -> {
      server.stop(handle2)
      process.sleep(500)
    }
    Error(_start_error) -> Nil
  }

  should.be_ok(result2)
}

/// Test: Stopping server multiple times is safe (idempotent)
pub fn stop_is_idempotent_test() {
  let port = 19_883

  let assert Ok(handle) = server.start(port)
  process.sleep(200)

  server.stop(handle)
  server.stop(handle)
  server.stop(handle)
  process.sleep(500)

  // If we get here without crashing, the test passes
  should.equal(1, 1)
}

/// Make a simple HTTP GET request using Erlang's httpc
/// Returns Ok(body) if successful, Error(reason) otherwise
@external(erlang, "http_test_ffi", "make_request")
fn make_http_request(url: String) -> Result(String, String)
