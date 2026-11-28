//// HTTP/2 guide: a test of the start of an HTTPS server with a missing
//// certificate
////
//// start is from test/snippets/server_tls.gleam: it serves HTTPS with
//// listen_with_handle, which returns the start error instead of stopping
//// the program.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/otp/actor
import gleam/result
import snippets/server_tls

pub fn tests() -> TestSuite {
  describe("server_tls.start", [
    it("names the certificate file that is missing", fn() {
      // Act
      let started =
        server_tls.start("priv/missing-cert.pem", "priv/missing-key.pem", 0)

      // Assert
      started
      |> result.map(fn(_handle) { Nil })
      |> should
      |> be_equal(
        Error(actor.InitFailed("TLS file not found: priv/missing-cert.pem")),
      )
      |> or_fail_with("a missing certificate should give InitFailed")
    }),
  ])
}
