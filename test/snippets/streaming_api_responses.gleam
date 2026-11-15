//// Streaming API reference: streaming responses
////
//// A download that streams bytes, a buffered and a streamed report, and an
//// upload controller that handles stream errors.

import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/yielder.{type Yielder}

pub fn download(_request: Request, _context, _services) -> Response {
  let stream =
    yielder.range(1, 1000)
    |> yielder.map(int_to_byte)

  stream_response(status.ok, stream, "application/octet-stream")
}

fn int_to_byte(number: Int) -> BitArray {
  <<number:8>>
}

pub fn create_buffered_report(line_count: Int) -> Response {
  // Builds the whole report in memory before the response is sent
  let report = string.repeat("report line\n", line_count)
  text_response(status.ok, report)
}

pub fn create_streamed_report(line_count: Int) -> Response {
  // Builds each line only when the client is ready for it
  let stream =
    yielder.repeat(<<"report line\n":utf8>>)
    |> yielder.take(line_count)
  stream_response(status.ok, stream, "text/plain")
}

pub type UploadError {
  InvalidChunk
}

pub fn upload(request: Request, _context, _services) -> Response {
  case request.stream {
    Some(stream) -> respond_to_upload(stream)
    None -> text_response(status.bad_request, "Expected streaming upload")
  }
}

fn respond_to_upload(stream: Yielder(BitArray)) -> Response {
  case process_stream_safely(stream) {
    Ok(message) -> text_response(status.ok, message)
    Error(InvalidChunk) ->
      text_response(status.unprocessable_content, "Upload must be UTF-8 text")
  }
}

fn process_stream_safely(
  stream: Yielder(BitArray),
) -> Result(String, UploadError) {
  stream
  |> yielder.try_fold(0, validate_and_add_chunk_size)
  |> result.map(format_total_bytes_message)
}

fn validate_and_add_chunk_size(
  total: Int,
  chunk: BitArray,
) -> Result(Int, UploadError) {
  case is_valid_chunk(chunk) {
    True -> Ok(total + bit_array.byte_size(chunk))
    False -> Error(InvalidChunk)
  }
}

fn is_valid_chunk(chunk: BitArray) -> Bool {
  result.is_ok(bit_array.to_string(chunk))
}

fn format_total_bytes_message(total: Int) -> String {
  "Processed " <> int.to_string(total) <> " bytes"
}
