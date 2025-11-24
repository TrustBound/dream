import dream/servers/mist/server.{bind, listen, router, services} as dream
import dream_mock_server/server as mock_server
import gleam/erlang/process
import gleam/io
import gleam/string
import router as app_router
import services

pub fn main() {
  // Start mock server for proxy endpoint
  case mock_server.start(9876) {
    Ok(_handle) -> {
      process.sleep(500)
    }
    Error(start_error) -> {
      io.println(
        "FATAL: Mock server failed to start: " <> string.inspect(start_error),
      )
      io.println(
        "The streaming capabilities example requires the mock server on port 9876",
      )
      exit_with_error()
    }
  }

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

@external(erlang, "erlang", "halt")
fn exit_with_error() -> Nil
