//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.
//// Multi-format example - demonstrating JSON, HTML, HTMX, CSV, and streaming responses

import context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services, tls} as dream
import gleam/io
import router as app_router
import services as app_services

pub fn main() {
  // Initialize services
  let app_services = app_services.initialize_services()

  // Start the server
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(app_services)
  |> router(app_router.create_router())
  |> bind("localhost")
  |> tls(certfile: "build/test_tls/cert.pem", keyfile: "build/test_tls/key.pem")
  |> listen(3000)

  io.println("Multi-format example server listening on http://localhost:3000")
  io.println("Try:")
  io.println("  /products/1       - HTML")
  io.println("  /products/1.json  - JSON")
  io.println("  /products/1.htmx  - HTMX partial")
  io.println("  /products/1.csv   - CSV")
  io.println("  /products.json    - JSON list")
  io.println("  /products.csv     - Streaming CSV")
}
