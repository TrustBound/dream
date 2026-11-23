//// Streaming API reference: the Request, RequestBody, ResponseBody and
//// Response types
////
//// Each function names every field or variant of a type, so the tests fail
//// when a field or variant changes.

import dream/http/header.{Header}
import dream/http/request.{
  type BodyReadError, type Request, type RequestBody, Http, Http1, Post, Request,
}
import dream/http/response.{
  type Response, type ResponseBody, Bytes, Response, Stream, Text,
}
import gleam/option.{None, Some}
import gleam/yielder.{type Yielder}

pub fn create_upload_request(
  chunks: Yielder(Result(BitArray, BodyReadError)),
) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/upload",
    query: "",
    params: [],
    host: None,
    port: None,
    remote_address: None,
    // A streaming route gets the request body as a stream of chunks. Each
    // item is Ok(chunk), or Error when the connection broke.
    body: request.Stream(chunks),
    headers: [],
    cookies: [],
    content_type: Some("application/octet-stream"),
    content_length: None,
  )
}

pub fn describe_body(body: ResponseBody) -> String {
  case body {
    // Buffered text: JSON, HTML, plain text
    Text(_text) -> "buffered text"
    // Buffered binary: images, PDFs
    Bytes(_bytes) -> "buffered bytes"
    // Streaming: large files, real-time data, CSV exports
    Stream(_chunks) -> "stream"
  }
}

pub fn create_csv_export_response(rows: Yielder(BitArray)) -> Response {
  Response(
    status: 200,
    body: Stream(rows),
    headers: [Header("Content-Type", "text/csv")],
    cookies: [],
    content_type: Some("text/csv"),
  )
}

pub fn describe_request_body(body: RequestBody) -> String {
  case body {
    // A normal route, body is valid UTF-8: JSON, form data, plain text
    request.Text(_text) -> "buffered text"
    // A normal route, body is not valid UTF-8: images, PDFs
    request.Bytes(_bytes) -> "buffered bytes"
    // A stream_route: uploads read chunk by chunk
    request.Stream(_chunks) -> "stream"
  }
}
