//// Reusable lifecycle hooks for tests.
////
//// These functions return `AssertionResult` so they can be passed directly
//// to `before_each`, `after_each`, etc.

import dream/router.{router}
import dream/servers/mist/server
import dream_http_client/client
import dream_test/process.{Ready, TimedOut, await_ready, quick_poll_config}
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import gleam/http
import gleam/int
import gleam/option.{None}

// ============================================================================
// Constants
// ============================================================================

/// The port used for test servers.
/// Tests can import this to know where to connect.
pub const test_server_port = 19_999

// ============================================================================
// Server Hooks
// ============================================================================

/// Starts a test server on `test_server_port` and waits for it to be ready.
/// Use with `before_each(start_server)`.
pub fn start_server() -> AssertionResult {
  let server_result =
    server.new()
    |> server.router(router())
    |> server.listen_with_handle(test_server_port)

  let ready_result = await_ready(quick_poll_config(), is_server_responding)

  case server_result, ready_result {
    Ok(_), Ready(_) -> AssertionOk
    Ok(_), TimedOut -> server_timeout_failure()
    Error(_), _ -> server_start_failure()
  }
}

fn is_server_responding() -> Bool {
  let result =
    client.new
    |> client.scheme(http.Http)
    |> client.host("127.0.0.1")
    |> client.port(test_server_port)
    |> client.path("/")
    |> client.send()

  case result {
    Ok(_response) -> True
    // Connection refused or timeout expected during startup polling
    Error(_connection_error) -> False
  }
}

fn server_timeout_failure() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "start_server",
    message: "Server not accepting connections on port "
      <> int.to_string(test_server_port),
    payload: None,
  ))
}

fn server_start_failure() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "start_server",
    message: "Failed to start test server on port "
      <> int.to_string(test_server_port),
    payload: None,
  ))
}

/// No-op - server is auto-cleaned by process isolation.
pub fn stop_server() -> AssertionResult {
  AssertionOk
}
// ============================================================================
// General Hooks
// ============================================================================
