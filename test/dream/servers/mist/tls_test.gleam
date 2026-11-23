//// Tests for HTTPS through dream's full server stack.
////
//// Starts a real dream server with `server.tls()` and a test certificate,
//// then sends requests over TLS that offer HTTP/2 or HTTP/1.1 in the TLS
//// handshake (ALPN). Each test asserts which protocol the server agreed to and
//// the exact response.

import dream/dream
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/server_start.{with_server}
import gleam/erlang/atom.{type Atom}
import gleam/option.{None, Some}
import gleam/otp/actor

pub fn tests() -> TestSuite {
  describe("tls", [
    it("agrees on HTTP/2 over TLS and answers the request", fn() {
      // Arrange
      let port = free_port()
      let #(certfile, keyfile) = write_certificate("build/test_tls")
      use handle <- with_server(port, fn() {
        server.new()
        |> server.router(tls_router())
        |> server.tls(certfile:, keyfile:)
        |> server.listen_with_handle(port)
      })

      // Act
      let result = request(port, atom.create("http2"), "/tls/hello")
      server.stop(handle)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#(atom.create("http2"), 200, <<"hello over tls":utf8>>)))
      |> or_fail_with("Expected an HTTP/2 response over TLS")
    }),
    it("answers HTTP/1.1 over TLS to clients that ask for it", fn() {
      // Arrange
      let port = free_port()
      let #(certfile, keyfile) = write_certificate("build/test_tls")
      use handle <- with_server(port, fn() {
        server.new()
        |> server.router(tls_router())
        |> server.tls(certfile:, keyfile:)
        |> server.listen_with_handle(port)
      })

      // Act
      let result = request(port, atom.create("http"), "/tls/hello")
      server.stop(handle)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#(atom.create("http"), 200, <<"hello over tls":utf8>>)))
      |> or_fail_with("Expected an HTTP/1.1 response over TLS")
    }),
    it("keeps TLS when settings are changed after tls()", fn() {
      // Arrange
      let port = free_port()
      let #(certfile, keyfile) = write_certificate("build/test_tls")
      use handle <- with_server(port, fn() {
        server.new()
        |> server.tls(certfile:, keyfile:)
        |> server.router(tls_router())
        |> server.bind("localhost")
        |> server.max_body_size(1000)
        |> server.listen_with_handle(port)
      })

      // Act
      let result = request(port, atom.create("http2"), "/tls/hello")
      server.stop(handle)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#(atom.create("http2"), 200, <<"hello over tls":utf8>>)))
      |> or_fail_with("Expected TLS to survive later settings")
    }),
    it("tls stores the certificate and key files", fn() {
      // Arrange
      let dream_instance = server.new()

      // Act
      let configured =
        server.tls(dream_instance, certfile: "cert.pem", keyfile: "key.pem")

      // Assert
      dream.get_tls(configured)
      |> should()
      |> be_equal(Some(dream.Tls(certfile: "cert.pem", keyfile: "key.pem")))
      |> or_fail_with("Expected the TLS files to be stored")
    }),
    it("new serves plain HTTP", fn() {
      // Arrange
      let dream_instance = server.new()

      // Act
      let tls = dream.get_tls(dream_instance)

      // Assert
      tls
      |> should()
      |> be_equal(None)
      |> or_fail_with("Expected no TLS by default")
    }),
    it("listen_with_handle fails when the certificate file is missing", fn() {
      // Arrange
      let port = free_port()
      let #(_certfile, keyfile) = write_certificate("build/test_tls")

      // Act
      let result =
        server.new()
        |> server.router(tls_router())
        |> server.tls(certfile: "build/test_tls/missing.pem", keyfile:)
        |> server.listen_with_handle(port)

      // Assert
      result
      |> should()
      |> be_equal(
        Error(actor.InitFailed("TLS file not found: build/test_tls/missing.pem")),
      )
      |> or_fail_with("Expected a start error for a missing certificate")
    }),
  ])
}

fn tls_router() {
  router()
  |> route(
    method: Get,
    path: "/tls/hello",
    controller: hello_controller,
    middleware: [],
  )
}

fn hello_controller(_request: Request, _context, _services) -> Response {
  text_response(200, "hello over tls")
}

fn request(
  port: Int,
  protocol: Atom,
  path: String,
) -> Result(#(Atom, Int, BitArray), Nil) {
  case request_ffi(port, protocol, path) {
    Ok(response) -> Ok(response)
    Error(_reason) -> Error(Nil)
  }
}

@external(erlang, "dream_tls_test_ffi", "write_certificate")
fn write_certificate(directory: String) -> #(String, String)

@external(erlang, "dream_tls_test_ffi", "request")
fn request_ffi(
  port: Int,
  protocol: Atom,
  path: String,
) -> Result(#(Atom, Int, BitArray), anything)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
