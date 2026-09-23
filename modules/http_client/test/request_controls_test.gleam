import dream_http_client/client
import dream_http_client_test
import gleam/erlang/process
import gleam/http
import gleam/string
import gleam/yielder
import gleeunit/should

@external(erlang, "tls_server_ffi", "start_once")
fn start_tls_server() -> Int

fn redirect_request() -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path("/redirect")
}

pub fn redirects_are_followed_by_default_test() {
  let assert Ok(response) = client.send(redirect_request())
  response.status |> should.equal(200)
}

pub fn redirects_can_be_disabled_test() {
  let request = redirect_request() |> client.follow_redirects(False)
  let assert Ok(response) = client.send(request)
  response.status |> should.equal(302)
}

pub fn pull_stream_follows_redirect_by_default_test() {
  let results = client.stream_yielder(redirect_request()) |> yielder.to_list()
  let assert [Ok(_), ..] = results
}

pub fn pull_stream_respects_disabled_redirects_test() {
  let request = redirect_request() |> client.follow_redirects(False)
  let results =
    client.stream_yielder(request) |> yielder.take(1) |> yielder.to_list()
  let assert [Error(reason)] = results
  { reason != "" } |> should.be_true()
}

pub fn callback_stream_respects_disabled_redirects_test() {
  let errors = process.new_subject()
  let request =
    redirect_request()
    |> client.follow_redirects(False)
    |> client.on_stream_error(fn(reason) { process.send(errors, reason) })

  let assert Ok(handle) = client.start_stream(request)
  let assert Ok(reason) = process.receive(errors, 3000)
  string.contains(reason, "302") |> should.be_true()
  client.await_stream(handle)
}

pub fn custom_ca_allows_local_https_request_test() {
  let request =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("localhost")
    |> client.port(start_tls_server())
    |> client.path("/")
    |> client.certificate_authority_file("test/fixtures/tls_ca.pem")

  let assert Ok(response) = client.send(request)
  response.body |> should.equal("ok")
}
