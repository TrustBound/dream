//// Blocking Request
////
//// Example snippet showing a simple blocking HTTP request.
////
//// Note: README shows api.example.com, but tests use localhost:9876 (mock server)

import dream_http_client/client
import gleam/http

pub fn simple_get() -> Result(String, String) {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/text")
  |> client.send()
}
