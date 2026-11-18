//// README: Builder Pattern
////
//// Every builder function on one POST request.

import dream_http_client/client.{
  type HttpResponse, type SendError, add_header, body, host, method, path, port,
  query, scheme, send, timeout,
}
import gleam/http

pub fn send_post() -> Result(HttpResponse, SendError) {
  let json_body = "{\"hello\":\"world\"}"

  client.new()
  // HTTP method
  |> method(http.Post)
  // HTTP or HTTPS
  |> scheme(http.Http)
  // Hostname (required)
  |> host("localhost")
  // Port (optional, defaults 80/443)
  |> port(9876)
  // Request path
  |> path("/post")
  // Query string
  |> query("page=1&limit=10")
  |> add_header("Content-Type", "application/json")
  // Request body
  |> body(json_body)
  // Timeout in ms (default: 30s)
  |> timeout(60_000)
  |> send()
}
