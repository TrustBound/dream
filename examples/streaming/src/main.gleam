//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3003)
}
