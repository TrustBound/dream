//// Blocking Request
////
//// Example snippet showing a simple blocking HTTP request.
////
//// Note: README shows api.example.com, but tests use localhost:9876 (mock server)

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
