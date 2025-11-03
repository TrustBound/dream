//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/servers/mist/server.{bind, listen, router} as dream
import examples/streaming/router.{create_router}
import gleam/erlang/process

pub fn main() {
  case
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
