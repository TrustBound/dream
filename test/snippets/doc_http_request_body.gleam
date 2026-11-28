//// Example for the doc comment of `request.RequestBody`.

import dream/http/request.{type Request, Bytes, Stream, Text}
import gleam/bit_array
import gleam/string
import gleam/yielder

pub fn body_size(request: Request) -> Int {
  case request.body {
    // A normal route, body is valid UTF-8
    Text(text) -> string.byte_size(text)
    // A normal route, body is not valid UTF-8
    Bytes(bytes) -> bit_array.byte_size(bytes)
    // A stream_route: add up the chunks as they arrive
    Stream(chunks) -> yielder.fold(chunks, 0, add_chunk_size)
  }
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}
