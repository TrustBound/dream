//// Streaming guide: Streaming Middleware
////
//// Middleware that transforms request and response streams, and a router
//// that uses both, as shown in docs/guides/streaming.md.

import dream/http/request.{type Request, Post, Request}
import dream/http/response.{
  type Response, Response, Stream, stream_response, text_response,
}
import dream/http/status
import dream/router.{type Router, router, stream_route}
import gleam/yielder

pub fn uppercase_incoming(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let transformed_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(transformed_request, context, services)
    }
    _ -> next(request, context, services)
  }
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  uppercase_bytes(chunk, <<>>)
}

fn uppercase_bytes(remaining: BitArray, uppercased: BitArray) -> BitArray {
  case remaining {
    <<byte, rest:bytes>> ->
      uppercase_bytes(rest, <<uppercased:bits, uppercase_byte(byte)>>)
    _ -> uppercased
  }
}

// Only the ASCII letters a to z change. Every byte of a multi-byte UTF-8
// character is 128 or more, so a character split across two chunks is kept.
fn uppercase_byte(byte: Int) -> Int {
  case byte >= 97 && byte <= 122 {
    True -> byte - 32
    False -> byte
  }
}

pub fn replace_space_outgoing(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)

  transform_response_stream(response)
}

fn transform_response_stream(response: Response) -> Response {
  case response.body {
    Stream(stream) ->
      Response(
        ..response,
        body: Stream(yielder.map(stream, replace_space_chunk)),
      )
    _ -> response
  }
}

// Works on bytes, so a UTF-8 character split across two chunks is kept
fn replace_space_chunk(chunk: BitArray) -> BitArray {
  replace_space_bytes(chunk, <<>>)
}

fn replace_space_bytes(remaining: BitArray, replaced: BitArray) -> BitArray {
  case remaining {
    <<" ":utf8, rest:bytes>> ->
      replace_space_bytes(rest, <<replaced:bits, "_":utf8>>)
    <<byte, rest:bytes>> -> replace_space_bytes(rest, <<replaced:bits, byte>>)
    _ -> replaced
  }
}

pub fn create_router() -> Router(context, services) {
  router()
  |> stream_route(
    method: Post,
    path: "/transform",
    controller: echo_stream,
    middleware: [uppercase_incoming, replace_space_outgoing],
  )
}

// The controller sends the request stream back as the response
pub fn echo_stream(request: Request, _context, _services) -> Response {
  case request.body {
    request.Stream(stream) -> stream_response(status.ok, stream, "text/plain")
    _ -> text_response(status.bad_request, "Expected streaming request")
  }
}
