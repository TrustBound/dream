//// HTTP response types and builders
////
//// Core response types and convenient functions for building common HTTP responses.

import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header, Header}
import gleam/option
import gleam/yielder

/// Response body types
///
/// Supports text, binary data, and streaming for different use cases:
/// - `Text` for JSON, HTML, plain text
/// - `Bytes` for images, PDFs, files
/// - `Stream` for large files, AI responses, real-time data
pub type ResponseBody {
  Text(String)
  Bytes(BitArray)
  Stream(yielder.Yielder(BitArray))
}

/// HTTP response type
///
/// The status field is an Int (HTTP status code like 200, 404, 500).
/// For typed status codes and response builders, use dream_helpers.
pub type Response {
  Response(
    status: Int,
    body: ResponseBody,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: option.Option(String),
  )
}

/// Create a plain text response
pub fn text_response(status: Int, body: String) -> Response {
  Response(
    status: status,
    body: Text(body),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// Create a JSON response
pub fn json_response(status: Int, body: String) -> Response {
  Response(
    status: status,
    body: Text(body),
    headers: [Header("Content-Type", "application/json; charset=utf-8")],
    cookies: [],
    content_type: option.Some("application/json; charset=utf-8"),
  )
}

/// Create an HTML response
pub fn html_response(status: Int, body: String) -> Response {
  Response(
    status: status,
    body: Text(body),
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
  )
}

/// Create a redirect response
pub fn redirect_response(status: Int, location: String) -> Response {
  Response(
    status: status,
    body: Text(""),
    headers: [Header("Location", location)],
    cookies: [],
    content_type: option.None,
  )
}

/// Create an empty response
pub fn empty_response(status: Int) -> Response {
  Response(
    status: status,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// Create a binary response for files, images, PDFs, etc
pub fn binary_response(
  status: Int,
  body: BitArray,
  content_type: String,
) -> Response {
  Response(
    status: status,
    body: Bytes(body),
    headers: [Header("Content-Type", content_type)],
    cookies: [],
    content_type: option.Some(content_type),
  )
}

/// Create a streaming response for large files or real-time data
pub fn stream_response(
  status: Int,
  stream: yielder.Yielder(BitArray),
  content_type: String,
) -> Response {
  Response(
    status: status,
    body: Stream(stream),
    headers: [Header("Content-Type", content_type)],
    cookies: [],
    content_type: option.Some(content_type),
  )
}

/// Create a Server-Sent Events (SSE) response
pub fn sse_response(
  status: Int,
  stream: yielder.Yielder(BitArray),
  content_type: String,
) -> Response {
  Response(
    status: status,
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
