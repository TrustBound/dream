//// Timeout Configuration
////
//// Example snippet showing how to configure request timeouts.
////
//// Note: README shows api.example.com, but tests use localhost:9876

import dream_http_client/client.{host, path, port, scheme, send, timeout}
import gleam/http

pub fn short_timeout() -> Result(String, String) {
  // Short timeout for quick APIs
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> timeout(5000)
  |> send()
}
