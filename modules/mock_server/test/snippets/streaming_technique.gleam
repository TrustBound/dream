//// README: Streaming Technique

import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/yielder

pub fn stream_fast(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 10)
    |> yielder.map(create_fast_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_fast_chunk(number: Int) -> BitArray {
  process.sleep(100)
  let line = "Chunk " <> int.to_string(number) <> "\n"
  bit_array.from_string(line)
}
