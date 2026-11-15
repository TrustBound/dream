//// Streaming guide: Ingress Streaming
////
//// Streaming routes and a controller that reads a streamed request body,
//// as shown in docs/guides/streaming.md.

import dream/http/request.{type Request, Post, Put}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router, stream_route}
import gleam/bit_array
import gleam/int
import gleam/option
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
  // Streaming route: the body is available as a Yielder(BitArray)
  |> stream_route(
    method: Post,
    path: "/upload_stream",
    controller: upload_stream,
    middleware: [],
  )
}

pub fn upload_buffered(request: Request, _context, _services) -> Response {
  let total_bytes = string.byte_size(request.body)
  create_upload_success_response(total_bytes)
}

pub fn upload_stream(request: Request, _context, _services) -> Response {
  request.stream
  |> option.map(count_stream_bytes)
  |> option.map(create_upload_success_response)
  |> option.unwrap(text_response(
    status.bad_request,
    "Expected streaming request body",
  ))
}

fn count_stream_bytes(stream: yielder.Yielder(BitArray)) -> Int {
  yielder.fold(stream, 0, add_chunk_size)
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}

fn create_upload_success_response(total_bytes: Int) -> Response {
  text_response(
    status.ok,
    "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
  )
}

// DON'T: assume every POST route streams. This body is buffered as a String.
pub fn create_buffered_upload_router() -> Router(context, services) {
  router()
  |> route(
    method: Post,
    path: "/upload",
    controller: upload_stream,
    middleware: [],
  )
}

// DO: mark streaming routes explicitly. This body is a Yielder(BitArray).
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
