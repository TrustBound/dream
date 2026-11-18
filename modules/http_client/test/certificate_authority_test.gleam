//// Certificate authority settings over HTTPS
////
//// Each test starts a Dream server with a test certificate signed by a test
//// certificate authority, then checks which requests trust it. Covers the
//// per-request setting, the client-wide default, and all three execution
//// modes (send, stream_yielder, start_stream).

import dream/http/request as dream_request
import dream/http/response as dream_response
import dream/router
import dream/servers/mist/server
import dream_http_client/client.{Http2Only}
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/yielder
import gleeunit/should

type Certificates {
  Certificates(
    port: Int,
    certificate_authority: String,
    other_certificate_authority: String,
  )
}

/// Starts a TLS server on its own port with its own certificates, runs the
/// test body, stops the server, and returns what the body returned. A new
/// port and a new certificate path per test keep one test from reusing
/// another test's server or pooled connection.
fn with_tls_server(port: Int, test_body: fn(Certificates) -> a) -> a {
  let #(certfile, keyfile, certificate_authority, other) =
    write_certificates("build/test_tls/" <> int.to_string(port))
  let assert Ok(handle) =
    server.new()
    |> server.router(
      router.router()
      |> router.route(
        method: dream_request.Get,
        path: "/tls",
        controller: hello,
        middleware: [],
      ),
    )
    |> server.tls(certfile:, keyfile:)
    |> server.listen_with_handle(port)
  let result = test_body(Certificates(port, certificate_authority, other))
  server.stop(handle)
  result
}

/// Runs the body with a client-wide default certificate authority file, and
/// puts the default transport configuration back afterwards.
fn with_default_certificate_authority_file(path: String, body: fn() -> a) -> a {
  client.transport_config()
  |> client.default_certificate_authority_file(path)
  |> client.configure_transport()
  let result = body()
  client.configure_transport(client.transport_config())
  result
}

fn hello(_request, _context, _services) {
  dream_response.text_response(200, "hello over tls")
}

fn tls_request(port: Int) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("localhost")
  |> client.port(port)
  |> client.path("/tls")
}

fn send_body(request: client.ClientRequest) -> Result(String, Nil) {
  request
  |> client.send
  |> result.map(fn(response) { response.body })
  |> result.replace_error(Nil)
}

pub fn send_trusts_the_certificate_authority_file_test() {
  {
    use certificates <- with_tls_server(19_960)
    tls_request(certificates.port)
    |> client.certificate_authority_file(certificates.certificate_authority)
    |> send_body
  }
  |> should.equal(Ok("hello over tls"))
}

pub fn send_rejects_a_server_from_an_unknown_certificate_authority_test() {
  {
    use certificates <- with_tls_server(19_961)
    tls_request(certificates.port)
    |> send_body
  }
  |> should.equal(Error(Nil))
}

pub fn send_rejects_a_server_from_another_certificate_authority_test() {
  {
    use certificates <- with_tls_server(19_962)
    tls_request(certificates.port)
    |> client.certificate_authority_file(
      certificates.other_certificate_authority,
    )
    |> send_body
  }
  |> should.equal(Error(Nil))
}

pub fn send_uses_the_default_certificate_authority_file_test() {
  {
    use certificates <- with_tls_server(19_963)
    use <- with_default_certificate_authority_file(
      certificates.certificate_authority,
    )
    tls_request(certificates.port)
    |> send_body
  }
  |> should.equal(Ok("hello over tls"))
}

pub fn request_certificate_authority_file_wins_over_the_default_test() {
  {
    use certificates <- with_tls_server(19_964)
    use <- with_default_certificate_authority_file(
      certificates.other_certificate_authority,
    )
    tls_request(certificates.port)
    |> client.certificate_authority_file(certificates.certificate_authority)
    |> send_body
  }
  |> should.equal(Ok("hello over tls"))
}

pub fn send_fails_when_the_certificate_authority_file_is_missing_test() {
  {
    use certificates <- with_tls_server(19_965)
    tls_request(certificates.port)
    |> client.certificate_authority_file("build/test_tls/missing.pem")
    |> send_body
  }
  |> should.equal(Error(Nil))
}

pub fn send_uses_http2_over_tls_with_the_certificate_authority_file_test() {
  {
    use certificates <- with_tls_server(19_966)
    tls_request(certificates.port)
    |> client.protocols(Http2Only)
    |> client.certificate_authority_file(certificates.certificate_authority)
    |> send_body
  }
  |> should.equal(Ok("hello over tls"))
}

pub fn stream_yielder_trusts_the_certificate_authority_file_test() {
  {
    use certificates <- with_tls_server(19_967)
    tls_request(certificates.port)
    |> client.certificate_authority_file(certificates.certificate_authority)
    |> client.stream_yielder
    |> yielder.to_list
    |> list.try_map(fn(chunk) { result.map(chunk, bytes_tree.to_bit_array) })
    |> result.map(fn(chunks) {
      bytes_tree.to_bit_array(bytes_tree.concat_bit_arrays(chunks))
    })
    |> result.replace_error(Nil)
  }
  |> should.equal(Ok(<<"hello over tls":utf8>>))
}

pub fn start_stream_trusts_the_certificate_authority_file_test() {
  {
    use certificates <- with_tls_server(19_968)
    let chunks = process.new_subject()
    let ended = process.new_subject()
    let started =
      tls_request(certificates.port)
      |> client.certificate_authority_file(certificates.certificate_authority)
      |> client.on_stream_chunk(fn(data) { process.send(chunks, data) })
      |> client.on_stream_end(fn(_headers) { process.send(ended, True) })
      |> client.on_stream_error(fn(_failure) { process.send(ended, False) })
      |> client.start_stream()
    case started, process.receive(ended, 10_000) {
      Ok(_handle), Ok(True) -> Ok(collect(chunks, <<>>))
      _started, _ended -> Error(Nil)
    }
  }
  |> should.equal(Ok(<<"hello over tls":utf8>>))
}

pub fn certificate_authority_file_is_not_set_by_default_test() {
  client.new()
  |> client.get_certificate_authority_file
  |> should.equal(None)
}

pub fn certificate_authority_file_sets_the_path_test() {
  client.new()
  |> client.certificate_authority_file("ca.pem")
  |> client.get_certificate_authority_file
  |> should.equal(Some("ca.pem"))
}

pub fn default_certificate_authority_file_is_not_set_by_default_test() {
  client.transport_config()
  |> client.get_default_certificate_authority_file
  |> should.equal(None)
}

pub fn default_certificate_authority_file_sets_the_path_test() {
  client.transport_config()
  |> client.default_certificate_authority_file("ca.pem")
  |> client.get_default_certificate_authority_file
  |> should.equal(Some("ca.pem"))
}

fn collect(subject: process.Subject(BitArray), received: BitArray) -> BitArray {
  case process.receive(subject, 100) {
    Ok(data) -> collect(subject, <<received:bits, data:bits>>)
    Error(Nil) -> received
  }
}

@external(erlang, "certificate_authority_ffi", "write_certificates")
fn write_certificates(directory: String) -> #(String, String, String, String)
