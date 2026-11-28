//// Example for the doc comment of `request.RequestBody`.

import dream/http/request.{type BodyReadError, type Request, Bytes, Stream, Text}
import gleam/bit_array
import gleam/result
import gleam/string
import gleam/yielder

pub fn body_size(request: Request) -> Result(Int, BodyReadError) {
  case request.body {
    // A normal route, body is valid UTF-8
    Text(text) -> Ok(string.byte_size(text))
    // A normal route, body is not valid UTF-8
    Bytes(bytes) -> Ok(bit_array.byte_size(bytes))
    // A stream_route: add up the chunks as they arrive. An Error item means
    // that the connection broke before the end, and try_fold stops there.
    Stream(chunks) -> yielder.try_fold(chunks, 0, add_chunk_size)
  }
}

fn add_chunk_size(
  total: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  total + bit_array.byte_size(chunk)
}
