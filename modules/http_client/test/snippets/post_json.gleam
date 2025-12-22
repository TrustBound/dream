//// POST Request with JSON
////
//// Example snippet showing how to POST JSON data.
////
//// Note: README shows api.example.com, but tests use localhost:9876 (mock server)

import dream_http_client/client.{
  add_header, body, host, method, path, port, scheme, send,
}
import gleam/http
import gleam/json

pub fn post_user() -> Result(String, String) {
  let user_json =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
    ])

  client.new()
  |> method(http.Post)
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/post")
  |> add_header("Content-Type", "application/json")
  |> body(json.to_string(user_json))
  |> send()
}
