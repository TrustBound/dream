//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/servers/mist/server.{bind, listen, router} as dream
import dream/core/context.{new_context}
import examples/streaming/router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router(), new_context)
  |> bind("localhost")
  |> listen(3000)
}
