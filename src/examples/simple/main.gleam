//// main.gleam

import dream/core/context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/simple/router.{create_router}
import examples/simple/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(context.AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
