//// POST Request with JSON
////
//// Example snippet showing how to POST JSON data.
////
//// Note: README shows api.example.com, but tests use localhost:9876 (mock server)

import dream_http_client/client
import gleam/http
import gleam/json

pub fn post_user() -> Result(String, String) {
  let user_json =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
    ])

  client.new
  |> client.method(http.Post)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(9876)
  |> client.path("/post")
  |> client.add_header("Content-Type", "application/json")
  |> client.body(json.to_string(user_json))
  |> client.send()
}
