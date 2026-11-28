//// Starts the parcels app on port 3000: `gleam run -m parcels/main`.
//// It needs `CARRIER_TOKEN`.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import parcels/router as parcels_router
import parcels/services as parcels_services

pub fn main() {
  let assert Ok(app_services) = parcels_services.initialize_services()
  let assert Ok(Nil) =
    dream.new()
    |> context(EmptyContext)
    |> services(app_services)
    |> router(parcels_router.create_router())
    |> bind("localhost")
    |> listen(3000)
}
