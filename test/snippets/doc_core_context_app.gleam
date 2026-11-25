//// Example for the `dream/context` module doc: the built-in `AppContext`.

import dream/context.{AppContext}
import dream/servers/mist/server.{context, listen, router}

pub fn start(my_router) {
  let assert Ok(Nil) =
    server.new()
    |> context(AppContext(request_id: ""))
    |> router(my_router)
    |> listen(3000)
}
