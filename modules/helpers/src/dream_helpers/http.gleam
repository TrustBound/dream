//// HTTP response builders
////
//// Convenient functions for building common HTTP responses.

import dream/core/http/transaction.{
  type Header, type Response, Bytes, Header, Response, Stream, Text,
}
import dream_helpers/statuses.{type Status}
import gleam/option
import gleam/yielder

/// Create a plain text response
pub fn text_response(status: Status, body: String) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Text(body),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// Create a JSON response
pub fn json_response(status: Status, body: String) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Text(body),
    headers: [Header("Content-Type", "application/json; charset=utf-8")],
    cookies: [],
    content_type: option.Some("application/json; charset=utf-8"),
  )
}

/// Create an HTML response
pub fn html_response(status: Status, body: String) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Text(body),
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
  )
}

/// Create a redirect response
pub fn redirect_response(status: Status, location: String) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Text(""),
    headers: [Header("Location", location)],
    cookies: [],
    content_type: option.None,
  )
}

/// Create an empty response
pub fn empty_response(status: Status) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// Create a binary response for files, images, PDFs, etc
pub fn binary_response(
  status: Status,
  body: BitArray,
  content_type: String,
) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Bytes(body),
    headers: [Header("Content-Type", content_type)],
    cookies: [],
    content_type: option.Some(content_type),
  )
}

/// Create a streaming response for large files or real-time data
pub fn stream_response(
  status: Status,
  stream: yielder.Yielder(BitArray),
  content_type: String,
) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Stream(stream),
    headers: [Header("Content-Type", content_type)],
    cookies: [],
    content_type: option.Some(content_type),
  )
}

/// Create a Server-Sent Events (SSE) response
pub fn sse_response(
  status: Status,
  stream: yielder.Yielder(BitArray),
  content_type: String,
) -> Response {
  Response(
    status: statuses.to_code(status),
    body: Stream(stream),
    headers: [
      Header("Content-Type", content_type),
      Header("Cache-Control", "no-cache"),
      Header("Connection", "keep-alive"),
    ],
    cookies: [],
    content_type: option.Some(content_type),
  )
}

