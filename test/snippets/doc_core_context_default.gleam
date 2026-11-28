//// Example for the `dream/context` module doc: the default context.

import dream/servers/mist/server.{listen, router}

pub fn start(my_router) {
  let assert Ok(Nil) =
    server.new()
    |> router(my_router)
    |> listen(3000)
}
