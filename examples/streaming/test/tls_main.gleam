//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.
//// main.gleam - Streaming example server
////
//// This example demonstrates how to use the Dream HTTP client
//// for both streaming and non-streaming requests.

import dream/servers/mist/server.{bind, listen, router, tls} as dream
import dream_mock_server/server as mock_server
import router.{create_router}

pub fn main() {
  // Start mock server for HTTP client examples
  let assert Ok(_mock_server) = mock_server.start(9876)

  // Start main example server
  let assert Ok(Nil) =
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    |> tls(
      certfile: "build/test_tls/cert.pem",
      keyfile: "build/test_tls/key.pem",
    )
    |> listen(3003)
}
