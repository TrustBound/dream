import dream/context.{EmptyContext}
import dream/servers/mist/server
import router
import services

/// Application entry point
///
/// Initializes services and starts the Dream server.
pub fn main() {
  let app_services = services.initialize()

  server.new()
  |> server.context(EmptyContext)
  |> server.services(app_services)
  |> server.router(router.create())
  |> server.listen(8080)
}
