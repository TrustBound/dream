import dream/servers/mist/server.{bind, listen, router, services} as dream
import dream_mock_server/server as mock_server
import gleam/io
import router as app_router
import services

pub fn main() {
  // Start mock server for proxy endpoint
  let assert Ok(_mock_server) = mock_server.start(9876)

  // Initialize services (empty for now)
  let services_instance = services.new()

  // Create router
  let router_instance = app_router.create()

  io.println("Starting streaming capabilities server on port 3000...")

  let assert Ok(Nil) =
    dream.new()
    |> services(services_instance)
    |> router(router_instance)
    |> bind("localhost")
    |> listen(3000)
}
