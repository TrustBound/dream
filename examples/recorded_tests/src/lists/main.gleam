//// Starts the lists app on port 3000: `gleam run -m lists/main`. It needs
//// `DATABASE_URL`, and the schema of `priv/schema.sql`.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import lists/router as lists_router
import lists/services as lists_services

pub fn main() {
  let assert Ok(app_services) = lists_services.initialize_services()
  let assert Ok(Nil) =
    dream.new()
    |> context(EmptyContext)
    |> services(app_services)
    |> router(lists_router.create_router())
    |> bind("localhost")
    |> listen(3000)
}
