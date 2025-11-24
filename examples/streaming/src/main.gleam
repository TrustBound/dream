//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/servers/mist/server.{bind, listen, router} as dream
import dream_mock_server/server as mock_server
import gleam/erlang/process
import gleam/io
import gleam/string
import router.{create_router}

pub fn main() {
  // Start mock server for HTTP client examples
  case mock_server.start(9876) {
    Ok(_handle) -> {
      process.sleep(500)
    }
    Error(start_error) -> {
      io.println(
        "FATAL: Mock server failed to start: " <> string.inspect(start_error),
      )
      io.println("The streaming example requires the mock server on port 9876")
      exit_with_error()
    }
  }

  // Start main example server
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen(3003)
}

@external(erlang, "erlang", "halt")
fn exit_with_error() -> Nil
