//// stream_controller.gleam
////
//// Controller for streaming example routes.
//// Follows Rails controller naming conventions.

import dream/core/context.{type AppContext}
import dream/core/http/statuses.{internal_server_error_status, ok_status}
import dream/core/http/transaction.{type Request, type Response, text_response}
import dream/core/router.{type EmptyServices}
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import dream/utilities/http/client/stream as stream_module
import gleam/bit_array
import gleam/bytes_tree
import gleam/http
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder

/// Index action - displays available routes
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(
    ok_status(),
    "Streaming Example Server\n\n"
      <> "Routes:\n"
      <> "  GET /stream - Stream a response from httpbin.org\n"
      <> "  GET /fetch - Fetch and return a response from httpbin.org\n",
  )
}

/// Show action - demonstrates streaming HTTP requests
pub fn show(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Make a streaming request to httpbin.org
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
    |> client.add_header("User-Agent", "Dream-Streaming-Example")

  // Stream the response chunks
  let chunks = stream_module.stream_request(req) |> yielder.to_list

  // Convert chunks to strings and concatenate
  let body_string =
    chunks
    |> list.map(chunk_to_string)
    |> string.join("")

  text_response(ok_status(), "Streamed response:\n\n" <> body_string)
}

/// New action - demonstrates non-streaming HTTP requests
pub fn new(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Make a non-streaming request to httpbin.org
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("httpbin.org")
    |> client.path("/get")
    |> client.add_header("User-Agent", "Dream-Fetch-Example")

  case fetch_module.request(req) {
    Ok(body) -> text_response(ok_status(), "Fetched response:\n\n" <> body)
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}

fn chunk_to_string(chunk: bytes_tree.BytesTree) -> String {
  bytes_tree.to_bit_array(chunk)
  |> bit_array.to_string
  |> result.unwrap("")
}
