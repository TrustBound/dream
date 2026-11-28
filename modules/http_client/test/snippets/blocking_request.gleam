//// README: Quick Start
////
//// A simple blocking GET request. The tests run it against the mock server
//// on localhost:9876.

import dream_http_client/client.{
  type HttpResponse, type SendError, host, method, path, port, scheme, send,
}
import gleam/http

pub fn simple_get() -> Result(HttpResponse, SendError) {
  client.new()
  |> method(http.Get)
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> send()
}
