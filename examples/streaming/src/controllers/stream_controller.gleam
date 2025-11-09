//// stream_controller.gleam
////
//// Controller for streaming example routes.
//// Follows Rails controller naming conventions.

import dream/core/context.{type AppContext}
import dream/core/http/transaction.{type Request, type Response}
import dream/core/router.{type EmptyServices}
import dream_http_client/client
import dream_http_client/client/fetch as fetch_module
import dream_http_client/client/stream as stream_module
import gleam/bit_array
import gleam/bytes_tree
import gleam/http
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder
import views/stream_view

/// Index action - displays available routes
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  stream_view.respond_index()
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

  stream_view.respond_stream(body_string)
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
    Ok(body) -> stream_view.respond_fetch(body)
    Error(error) -> stream_view.respond_error(error)
  }
}

fn chunk_to_string(chunk: bytes_tree.BytesTree) -> String {
  bytes_tree.to_bit_array(chunk)
  |> bit_array.to_string
  |> result.unwrap("")
}
