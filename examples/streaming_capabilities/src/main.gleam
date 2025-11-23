import dream/servers/mist/server.{bind, listen, router, services} as dream
import gleam/io
import router as app_router
import services

pub fn main() {
  // Initialize services (empty for now)
  let services_instance = services.new()

  // Create router
  let router_instance = app_router.create()

  io.println("Starting streaming capabilities server on port 3000...")

  dream.new()
  |> services(services_instance)
  |> router(router_instance)
  |> bind("localhost")
  |> listen(3000)
}
