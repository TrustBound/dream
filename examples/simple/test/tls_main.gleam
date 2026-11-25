//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import dream/servers/mist/server.{bind, listen, router, tls} as dream
import router.{create_router}

pub fn main() {
  let assert Ok(Nil) =
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> tls(
      certfile: "build/test_tls/cert.pem",
      keyfile: "build/test_tls/key.pem",
    )
    |> listen(3000)
}
