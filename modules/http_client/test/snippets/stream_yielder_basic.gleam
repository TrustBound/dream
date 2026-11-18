//// README: Yielder Streaming - stream_yielder()
////
//// Counts the bytes of a streamed response, and stops at the first failure.

import dream_http_client/client.{
  type StreamFailure, host, path, port, scheme, stream_yielder,
}
import gleam/bytes_tree.{type BytesTree}
import gleam/http
import gleam/result
import gleam/yielder

pub fn count_stream_bytes() -> Result(Int, StreamFailure) {
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/stream/fast")
  |> stream_yielder()
  |> yielder.try_fold(0, add_chunk_size)
}

fn add_chunk_size(
  total: Int,
  chunk_result: Result(BytesTree, StreamFailure),
) -> Result(Int, StreamFailure) {
  use chunk <- result.map(chunk_result)
  total + bytes_tree.byte_size(chunk)
}
