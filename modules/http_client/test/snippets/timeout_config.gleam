//// Timeout Configuration
////
//// Example snippet showing how to configure request timeouts.
////
//// Note: README shows api.example.com, but tests use localhost:9876

import dream_http_client/client
import gleam/http

pub fn short_timeout() -> Result(String, String) {
  // Short timeout for quick APIs
  client.new
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/text")
  |> client.timeout(5000)
  |> client.send()
}
