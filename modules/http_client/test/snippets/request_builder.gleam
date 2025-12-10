//// Request Builder Pattern
////
//// Example snippet showing the builder pattern for request configuration.
////
//// Note: README shows api.example.com, but tests use localhost:9876

import dream_http_client/client
import gleam/http
import gleam/json

pub fn build_complex_request() -> Result(String, String) {
  let json_body =
    json.object([#("query", json.string("test")), #("limit", json.int(10))])

  let token = "secret_token"

  client.new
  |> client.method(http.Post)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/post")
  |> client.query("page=1&limit=10")
  |> client.add_header("Content-Type", "application/json")
  |> client.add_header("Authorization", "Bearer " <> token)
  |> client.body(json.to_string(json_body))
  |> client.timeout(60_000)
  |> client.send()
}
