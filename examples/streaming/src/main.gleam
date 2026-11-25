//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/servers/mist/server.{bind, listen, router} as dream
import dream_mock_server/server as mock_server
import router.{create_router}

pub fn main() {
  // Start mock server for HTTP client examples
  let assert Ok(_mock_server) = mock_server.start(9876)

  // Start main example server
  let assert Ok(Nil) =
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3003)
}
