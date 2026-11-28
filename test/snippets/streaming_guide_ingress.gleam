//// Streaming guide: Ingress Streaming
////
//// Streaming routes and a controller that reads a streamed request body,
//// as shown in docs/guides/streaming.md.

import dream/http/request.{
  type BodyReadError, type Request, Bytes, MalformedBody, Post, Put, Stream,
  Text,
}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/result
import gleam/string
import gleam/yielder

pub fn create_router() -> Router(context, services) {
  router()
  // Regular route: the body is buffered as a String
  |> route(
    method: Post,
    path: "/upload",
    controller: upload_buffered,
    middleware: [],
  )
  // Streaming route: the body is a Yielder of Result(BitArray, BodyReadError)
  |> stream_route(
    method: Post,
    path: "/upload_stream",
    controller: upload_stream,
    middleware: [],
  )
}

pub fn upload_buffered(request: Request, _context, _services) -> Response {
  case request.body {
    Text(text) -> create_upload_response(Ok(string.byte_size(text)))
    Bytes(bytes) -> create_upload_response(Ok(bit_array.byte_size(bytes)))
    Stream(_chunks) ->
      text_response(status.bad_request, "Expected buffered request body")
  }
}

pub fn upload_stream(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) ->
      count_stream_bytes(stream)
      |> create_upload_response
    _ -> text_response(status.bad_request, "Expected streaming request body")
  }
}

// try_fold stops at the first Error item
fn count_stream_bytes(
  stream: yielder.Yielder(Result(BitArray, BodyReadError)),
) -> Result(Int, BodyReadError) {
  yielder.try_fold(stream, 0, add_chunk_size)
}

fn add_chunk_size(
  total: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  total + bit_array.byte_size(chunk)
}

fn create_upload_response(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    // The connection broke before the client sent the whole body
    Error(MalformedBody) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}

// DON'T: assume every POST route streams. This body arrives buffered.
pub fn create_buffered_upload_router() -> Router(context, services) {
  router()
  |> route(
    method: Post,
    path: "/upload",
    controller: upload_stream,
    middleware: [],
  )
}

// DO: mark streaming routes explicitly. This body is a Yielder of Results.
pub fn create_streaming_upload_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload_stream,
    middleware: [],
  )
}

// stream_route works with any HTTP method
pub fn create_file_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Put,
    path: "/files/:name",
    controller: upload_stream,
    middleware: [],
  )
}
