//// Streaming guide: Common Pitfalls
////
//// Bad and good streaming code, as shown in the "Common Pitfalls" section of
//// docs/guides/streaming.md. The bad functions compile and run, but they do
//// extra work or hide a missing request body.

import dream/http/request.{type Request, Stream}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/yielder.{type Yielder}

// BAD: the stream is read twice
pub fn download_with_line_count(
  _request: Request,
  _context,
  _services,
) -> Response {
  let stream = yielder.range(1, 100) |> yielder.map(number_to_line)
  let line_count = yielder.length(stream)
  let first_line = "Lines: " <> int.to_string(line_count) <> "\n"
  let body = yielder.prepend(stream, <<first_line:utf8>>)
  stream_response(status.ok, body, "text/plain")
}

fn number_to_line(number: Int) -> BitArray {
  let line = "Line " <> int.to_string(number) <> "\n"
  <<line:utf8>>
}

// BAD: defeats the purpose of streaming
pub fn send_buffered(stream: Yielder(BitArray)) -> Response {
  let all_chunks = yielder.to_list(stream)
  stream_response(status.ok, yielder.from_list(all_chunks), "text/plain")
}

// GOOD: keep it lazy
pub fn send_lazy(stream: Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/plain")
}

// BAD: a buffered body becomes an empty upload
pub fn upload_without_check(request: Request, _context, _services) -> Response {
  let stream = case request.body {
    Stream(stream) -> stream
    _ -> yielder.empty()
  }
  save_stream(stream)
}

// GOOD: reject a body that is not a stream
pub fn upload_with_check(request: Request, _context, _services) -> Response {
  case request.body {
    Stream(stream) -> save_stream(stream)
    _ -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn save_stream(stream: Yielder(BitArray)) -> Response {
  let total_bytes = yielder.fold(stream, 0, add_chunk_size)
  text_response(status.ok, "Saved " <> int.to_string(total_bytes) <> " bytes")
}

fn add_chunk_size(total_bytes: Int, chunk: BitArray) -> Int {
  total_bytes + bit_array.byte_size(chunk)
}
