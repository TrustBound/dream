//// OpenSearch HTTP client

import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/result
import gleam/string

/// OpenSearch client configuration
pub type Client {
  Client(base_url: String)
}

/// Create a new OpenSearch client
pub fn new(base_url: String) -> Client {
  let trimmed = case string.ends_with(base_url, "/") {
    True -> string.drop_end(base_url, 1)
    False -> base_url
  }
  Client(base_url: trimmed)
}

/// Send HTTP request to OpenSearch
pub fn send_request(
  client: Client,
  method: http.Method,
  path: String,
  body: String,
) -> Result(String, String) {
  let url = client.base_url <> path

  let assert Ok(req) = request.to(url)

  req
  |> request.set_method(method)
  |> request.set_body(body)
  |> request.prepend_header("content-type", "application/json")
  |> httpc.send()
  |> result.map_error(error_to_string)
  |> result.map(extract_body)
}

fn extract_body(response: Response(String)) -> String {
  response.body
}

fn error_to_string(_error: httpc.HttpError) -> String {
  "HTTP request failed"
}
