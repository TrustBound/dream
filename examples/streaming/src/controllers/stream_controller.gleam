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
  // Make a streaming request to mock server
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/stream/fast")
    |> client.add_header("User-Agent", "Dream-Streaming-Example")
    |> client.timeout(15_000)

  // Stream the response chunks
  let chunks = client.stream_yielder(req) |> yielder.to_list

  // Convert chunks to strings and concatenate
  let body_result = chunks |> list.try_map(convert_chunk_result)

  case body_result {
    Ok(strings) -> {
      let body_string = string.join(strings, "")
      text_response(status.ok, stream_view.format_stream(body_string))
    }
    Error(error) ->
      text_response(
        status.internal_server_error,
        stream_view.format_error(error),
      )
  }
}

/// New action - demonstrates non-streaming HTTP requests
pub fn new(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Make a non-streaming request to mock server
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/json")
    |> client.add_header("User-Agent", "Dream-Fetch-Example")
    |> client.timeout(5000)

  case client.send(req) {
    Ok(body) -> text_response(status.ok, stream_view.format_fetch(body))
    Error(error) ->
      text_response(
        status.internal_server_error,
        stream_view.format_error(error),
      )
  }
}

fn convert_chunk_result(
  result: Result(bytes_tree.BytesTree, String),
) -> Result(String, String) {
  case result {
    Ok(chunk) -> Ok(chunk_to_string(chunk))
    Error(err) -> Error(err)
  }
}

fn chunk_to_string(chunk: bytes_tree.BytesTree) -> String {
  bytes_tree.to_bit_array(chunk)
  |> bit_array.to_string
  |> result.unwrap("")
}
