//// Starts the mock server over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `standalone`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import dream/servers/mist/server.{bind, listen, router, tls} as dream
import dream_mock_server/router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> tls(certfile: "build/test_tls/cert.pem", keyfile: "build/test_tls/key.pem")
  |> listen(3004)
}
