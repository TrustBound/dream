//// README: Per-Request Settings
////
//// A connect timeout and redirect handling on one request each.

import dream_http_client/client.{type HttpResponse, type SendError}
import gleam/http

// Set TCP connection timeout (default: 15000ms)
pub fn fetch_with_connect_timeout() -> Result(HttpResponse, SendError) {
  client.new()
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/text")
  |> client.connect_timeout(5000)
  |> client.send()
}

// Disable automatic redirect following (default: True)
pub fn fetch_without_redirect() -> Result(HttpResponse, SendError) {
  client.new()
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/redirect/302")
  |> client.auto_redirect(False)
  |> client.send()
}
