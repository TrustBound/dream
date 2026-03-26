//// Demonstrates using HTTP/2 over cleartext (h2c) with protocol preference.

import dream_http_client/client.{type HttpResponse, type SendError, Http2Only}
import gleam/http

pub fn h2c_request() -> Result(HttpResponse, SendError) {
  client.new()
  |> client.scheme(http.Http)
  |> client.host("internal-service.local")
  |> client.port(8080)
  |> client.path("/api/data")
  |> client.protocols(Http2Only)
  |> client.send()
}
