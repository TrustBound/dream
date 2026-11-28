//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import dream/servers/mist/server.{bind, listen, router, tls} as dream
import gleam/io
import router as app_router
import simplifile

pub fn main() {
  // Debug: Log working directory
  case simplifile.current_directory() {
    Ok(dir) -> io.println("Server starting from: " <> dir)
    Error(_) -> io.println("Could not determine directory")
  }

  // Debug: Check if public/ exists
  case simplifile.is_directory("./public") {
    Ok(True) -> io.println("✓ ./public exists")
    _ -> io.println("✗ ./public NOT FOUND")
  }

  // Debug: Check if assets/ exists
  case simplifile.is_directory("./assets") {
    Ok(True) -> io.println("✓ ./assets exists")
    _ -> io.println("✗ ./assets NOT FOUND")
  }

  let router_instance = app_router.create_router()

  io.println("=== STARTING SERVER ON PORT 3000 ===")

  dream.new()
  |> router(router_instance)
  |> bind("localhost")
  |> tls(certfile: "build/test_tls/cert.pem", keyfile: "build/test_tls/key.pem")
  |> listen(3000)
}
