//// Example for the `dream/context` module doc: `EmptyContext` set
//// explicitly.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{context, listen, router}

pub fn start(my_router) {
  let assert Ok(Nil) =
    server.new()
    |> context(EmptyContext)
    |> router(my_router)
    |> listen(3000)
}
