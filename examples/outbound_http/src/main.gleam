//// Starts the forecasts app on port 3000: `gleam run -m main`.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import router as app_router
import services as app_services

pub fn main() {
  let assert Ok(Nil) =
    dream.new()
    |> context(EmptyContext)
    |> services(app_services.initialize_services())
    |> router(app_router.create_router())
    |> bind("localhost")
    |> listen(3000)
}
