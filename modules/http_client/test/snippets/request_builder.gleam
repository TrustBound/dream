//// Request Builder Pattern
////
//// Example snippet showing the builder pattern for request configuration.
////
//// Note: README shows api.example.com, but tests use localhost:9876

import dream_http_client/client.{
  add_header, body, host, method, path, port, query, scheme, send, timeout,
}
import gleam/http
import gleam/json

pub fn build_complex_request() -> Result(String, String) {
  let json_body =
    json.object([#("query", json.string("test")), #("limit", json.int(10))])

  let token = "secret_token"

  client.new()
  |> method(http.Post)
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/post")
  |> query("page=1&limit=10")
  |> add_header("Content-Type", "application/json")
  |> add_header("Authorization", "Bearer " <> token)
  |> body(json.to_string(json_body))
  |> timeout(60_000)
  |> send()
}
