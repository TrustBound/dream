//// Streaming guide: request and response types
////
//// Response bodies, a stream response builder and the streaming request
//// fields, as shown in docs/guides/streaming.md.

import dream/http/request.{type Request, Request}
import dream/http/response.{
  type Response, type ResponseBody, Bytes, Stream, Text, stream_response,
}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/option.{Some}
import gleam/yielder.{type Yielder}

// Buffered text response: the entire response is in memory
pub fn create_text_body() -> ResponseBody {
  Text("Hello, World!")
}

// Buffered binary response: the entire file is in memory
pub fn create_bytes_body(image_data: BitArray) -> ResponseBody {
  Bytes(image_data)
}

// Streaming response: chunks are made on demand
pub fn create_stream_body(file_chunks: Yielder(BitArray)) -> ResponseBody {
  Stream(file_chunks)
}

// Stream with a custom content type
pub fn create_csv_download(csv_rows: Yielder(BitArray)) -> Response {
  stream_response(status.ok, csv_rows, "text/csv")
}

// A streaming route gives the controller a request like this one
pub fn create_streaming_request(
  request: Request,
  chunks: Yielder(BitArray),
) -> Request {
  Request(
    ..request,
    // Buffered body: empty for streaming routes
    body: "",
    // Streaming body: Some for streaming routes
    stream: Some(chunks),
  )
}

pub fn describe_body(body: ResponseBody) -> String {
  case body {
    // Buffered text response
    Text(text) -> "Text: " <> text
    // Buffered binary response
    Bytes(bytes) -> "Bytes: " <> int.to_string(bit_array.byte_size(bytes))
    // Streaming response
    Stream(_chunks) -> "Stream"
  }
}
