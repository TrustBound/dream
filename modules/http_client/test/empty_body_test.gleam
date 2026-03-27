//// Empty body regression tests
////
//// Verifies that PUT, POST, PATCH, GET, and DELETE all complete successfully
//// when sent with no request body. Previously, PUT/POST/PATCH hung forever
//// due to gun's inconsistent method-specific dispatch for empty bodies.

import dream_http_client/client
import dream_http_client_test
import gleam/http
import gleeunit/should

fn mock_request(method: http.Method, path: String) -> client.ClientRequest {
  client.new()
  |> client.method(method)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
  |> client.timeout(5000)
}

pub fn send_put_empty_body_succeeds_test() {
  let req = mock_request(http.Put, "/put")

  let assert Ok(resp) = client.send(req)

  resp.status |> should.equal(200)
}

pub fn send_post_empty_body_succeeds_test() {
  let req = mock_request(http.Post, "/post")

  let assert Ok(resp) = client.send(req)

  resp.status |> should.equal(201)
}

pub fn send_patch_empty_body_succeeds_test() {
  let req = mock_request(http.Patch, "/patch")

  let assert Ok(resp) = client.send(req)

  resp.status |> should.equal(200)
}

pub fn send_get_empty_body_succeeds_test() {
  let req = mock_request(http.Get, "/text")

  let assert Ok(resp) = client.send(req)

  resp.status |> should.equal(200)
}

pub fn send_delete_empty_body_succeeds_test() {
  let req = mock_request(http.Delete, "/delete")

  let assert Ok(resp) = client.send(req)

  resp.status |> should.equal(200)
}
