//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import dream/context.{EmptyContext}
import dream/servers/mist/server
import router
import services

pub fn main() {
  let app_services = services.initialize()

  server.new()
  |> server.context(EmptyContext)
  |> server.services(app_services)
  |> server.router(router.create())
  |> server.tls(
    certfile: "build/test_tls/cert.pem",
    keyfile: "build/test_tls/key.pem",
  )
  |> server.listen(8081)
}
