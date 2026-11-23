//// Starts a test server so that a failed start fails the test with a
//// readable message.
////
//// When a server fails to start, its supervisor can send an exit signal to
//// the process that started it. Without trap_exit, that signal stops the test
//// process before the test can report the start error. `with_server` traps
//// exits while the server starts, so the test fails with the port and the
//// start error.

import dream/servers/mist/server.{type ServerHandle}
import dream_test/matchers.{fail_with}
import dream_test/types.{type AssertionResult}
import gleam/int
import gleam/otp/actor
import gleam/string

/// Calls `start`, then calls `body` with the handle of the started server.
/// If the server does not start, the test fails with the port and the start
/// error, and `body` is not called.
pub fn with_server(
  port: Int,
  start: fn() -> Result(ServerHandle, actor.StartError),
  body: fn(ServerHandle) -> Result(AssertionResult, String),
) -> Result(AssertionResult, String) {
  case call_trapping_exits(start) {
    Ok(handle) -> body(handle)
    Error(error) ->
      Ok(fail_with(
        "The server did not start on port "
        <> int.to_string(port)
        <> ": "
        <> string.inspect(error),
      ))
  }
}

@external(erlang, "port_ffi", "call_trapping_exits")
fn call_trapping_exits(
  start: fn() -> Result(ServerHandle, actor.StartError),
) -> Result(ServerHandle, actor.StartError)
