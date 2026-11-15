//// Streaming API reference: streaming routes, middleware and server limits
////
//// A router with streaming routes, middleware that transforms request and
//// response streams, and a server with a larger buffered body limit.

import dream/http/header.{type Header}
import dream/http/request.{type Request, Post, Put, Request}
import dream/http/response.{type Response, Response, Stream, text_response}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import dream/servers/mist/server
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/yielder

pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: upload,
    middleware: [],
  )
  |> stream_route(
    method: Put,
    path: "/files/:id",
    controller: replace_file,
    middleware: [require_api_key],
  )
}

pub fn upload(request: Request, _context, _services) -> Response {
  let chunks = option.unwrap(request.stream, yielder.empty())
  let total_bytes = yielder.fold(chunks, 0, add_chunk_size)
  text_response(
    status.ok,
    "Received " <> int.to_string(total_bytes) <> " bytes",
  )
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}

pub fn replace_file(_request: Request, _context, _services) -> Response {
  text_response(status.ok, "File replaced")
}

pub fn require_api_key(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let has_key = list.any(request.headers, is_api_key_header)
  case has_key {
    True -> next(request, context, services)
    False -> text_response(status.unauthorized, "Missing API key")
  }
}

fn is_api_key_header(header: Header) -> Bool {
  header.name == "X-Api-Key"
}

pub fn uppercase_incoming(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let new_request = Request(..request, stream: Some(uppercase_stream))
      next(new_request, context, services)
    }
    None -> next(request, context, services)
  }
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  chunk
  |> bit_array.to_string()
  |> result.unwrap("")
  |> string.uppercase()
  |> bit_array.from_string()
}

pub fn end_outgoing_chunks_with_newline(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)

  case response.body {
    Stream(stream) -> {
      let newline_stream = yielder.map(stream, append_newline)
      Response(..response, body: Stream(newline_stream))
    }
    _ -> response
  }
}

fn append_newline(chunk: BitArray) -> BitArray {
  bit_array.append(chunk, <<"\n":utf8>>)
}

pub fn create_large_payload_server() {
  server.new()
  // 100MB for large JSON payloads
  |> server.max_body_size(100_000_000)
}
