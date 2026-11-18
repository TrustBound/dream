//// Streaming quick reference: stream middleware
////
//// Middleware that transforms the incoming and the outgoing stream, as shown
//// in docs/guides/streaming-quick-reference.md.

import dream/http/request.{type Request, Request}
import dream/http/response.{type Response, Response, Stream}
import gleam/yielder

pub fn uppercase_middleware(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  case request.body {
    request.Stream(stream) -> {
      let uppercase_stream = yielder.map(stream, uppercase_chunk)
      let new_request =
        Request(..request, body: request.Stream(uppercase_stream))
      next(new_request, context, services)
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

pub fn line_endings_middleware(
  request: Request,
  context: context,
  services: services,
  next: fn(Request, context, services) -> Response,
) -> Response {
  let response = next(request, context, services)

  case response.body {
    Stream(stream) -> {
      let converted_stream =
        stream
        |> yielder.map(convert_line_endings)

      Response(..response, body: Stream(converted_stream))
    }
    _ -> response
  }
}

// Works on bytes, so a UTF-8 character split across two chunks is kept
fn convert_line_endings(chunk: BitArray) -> BitArray {
  convert_line_ending_bytes(chunk, <<>>)
}

fn convert_line_ending_bytes(
  remaining: BitArray,
  converted: BitArray,
) -> BitArray {
  case remaining {
    <<"\n":utf8, rest:bytes>> ->
      convert_line_ending_bytes(rest, <<converted:bits, "\r\n":utf8>>)
    <<byte, rest:bytes>> ->
      convert_line_ending_bytes(rest, <<converted:bits, byte>>)
    _ -> converted
  }
}
