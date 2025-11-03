//// Custom Context Example
////
//// This example demonstrates how to use custom context types with Dream.
//// It shows authentication middleware that populates a custom context
//// with user information, which is then accessed by controllers.

import dream/servers/mist/server.{bind, listen, router} as dream
import examples/custom_context/context.{new_context}
import examples/custom_context/router.{create_router}
import gleam/erlang/process

pub fn main() {
  case
    dream.new()
    |> router(create_router(), new_context)
    |> bind("localhost")
    |> listen(3001)
  {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
