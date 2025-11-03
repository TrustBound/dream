//// main.gleam

import dream/core/context.{new_context}
import dream/servers/mist/server.{bind, listen, router} as dream
import examples/simple/router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router(), new_context)
  |> bind("localhost")
  |> listen(3000)
}
