//// stream_controller.gleam
////
//// Controller for streaming example routes.
//// Follows Rails controller naming conventions.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import dream_http_client/client
import dream_http_client/fetch
import dream_http_client/stream
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
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, stream_view.format_index())
}

/// Show action - demonstrates streaming HTTP requests
pub fn show(
  _request: Request,
  _context: EmptyContext,
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
  let chunks = stream.stream_request(req) |> yielder.to_list

  // Convert chunks to strings and concatenate
  let body_string =
    chunks
    |> list.map(chunk_to_string)
    |> string.join("")

  text_response(status.ok, stream_view.format_stream(body_string))
}

/// New action - demonstrates non-streaming HTTP requests
pub fn new(
  _request: Request,
  _context: EmptyContext,
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

  case fetch.request(req) {
    Ok(body) -> text_response(status.ok, stream_view.format_fetch(body))
    Error(error) ->
      text_response(
        status.internal_server_error,
        stream_view.format_error(error),
      )
  }
}

fn chunk_to_string(chunk: bytes_tree.BytesTree) -> String {
  bytes_tree.to_bit_array(chunk)
  |> bit_array.to_string
  |> result.unwrap("")
}
