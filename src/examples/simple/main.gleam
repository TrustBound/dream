//// main.gleam

import dream/core/context.{new_context}
import dream/servers/mist/server.{bind, listen, router} as dream
import examples/simple/router.{create_router}
import gleam/erlang/process

pub fn main() {
  case
    dream.new()
    |> router(create_router(), new_context)
    |> bind("localhost")
    |> listen(3000)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
