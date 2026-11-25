//// HTTP response types and builders
////
//// Guides: [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html), [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html) and [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html).
////
//// Core response types and convenient functions for building common HTTP responses.
//// This module provides builders for text, JSON, HTML, binary, and streaming responses.
////
//// ## Quick Examples
////
//// ### Build responses <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_response_module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/response
//// import dream/http/status
//// import gleam/json
////
//// // Text response
//// pub fn greeting() {
////   response.text_response(status.ok, "Hello, World!")
//// }
////
//// // JSON response
//// pub fn user(user_json: json.Json) {
////   response.json_response(status.ok, json.to_string(user_json))
//// }
////
//// // HTML response
//// pub fn welcome_page() {
////   response.html_response(status.ok, "<h1>Welcome</h1>")
//// }
////
//// // Redirect
//// pub fn login_redirect() {
////   response.redirect_response(status.see_other, "/login")
//// }
//// ```

import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header, Header}
import gleam/option
import gleam/yielder

/// Response body types
///
/// Supports text, binary data, and streaming for different use cases:
/// - `Text(String)` - For JSON, HTML, plain text, XML, etc.
/// - `Bytes(BitArray)` - For images, PDFs, files, binary data
/// - `Stream(Yielder)` - For large files, real-time data, AI responses
///
/// Most responses use `Text` since JSON and HTML are text-based.
/// Use `Bytes` for binary files and `Stream` for large or real-time data.
///
/// ## Examples
///
/// ### Response bodies <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_response_body.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{type ResponseBody, Bytes, Stream, Text}
/// import gleam/json
/// import gleam/yielder.{type Yielder}
///
/// pub fn response_bodies(
///   data: json.Json,
///   image_data: BitArray,
///   file_chunks: Yielder(BitArray),
/// ) -> List(ResponseBody) {
///   [
///     // Text responses (most common)
///     Text("Hello, World!"),
///     Text(json.to_string(data)),
///     // Binary response
///     Bytes(image_data),
///     // Streaming response
///     Stream(file_chunks),
///   ]
/// }
/// ```
pub type ResponseBody {
  Text(String)
  Bytes(BitArray)
  Stream(yielder.Yielder(BitArray))
}

/// HTTP response type
///
/// Represents a complete HTTP response with status code, body, headers, and cookies.
/// Use the response builder functions (`text_response`, `json_response`, etc.) rather
/// than constructing this directly.
///
/// ## Fields
///
/// - `status`: HTTP status code (200, 404, 500, etc.) - use constants from `dream/http/status`
/// - `body`: Response body as Text, Bytes, or Stream
/// - `headers`: List of HTTP headers
/// - `cookies`: List of cookies to set (each becomes a separate `Set-Cookie` header)
/// - `content_type`: Content-Type header value (automatically set by builders)
///
/// ## Example
///
/// ### Builder or constructor <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_response_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
/// import dream/http/response.{type Response, Response, Text}
/// import dream/http/status
/// import gleam/option.{Some}
///
/// // Using builder (recommended)
/// pub fn with_builder(user_json: String) -> Response {
///   response.json_response(status.ok, user_json)
/// }
///
/// // Constructing directly (not recommended)
/// pub fn by_hand(user_json: String) -> Response {
///   Response(
///     status: 200,
///     body: Text(user_json),
///     headers: [Header("Content-Type", "application/json; charset=utf-8")],
///     cookies: [],
///     content_type: Some("application/json; charset=utf-8"),
///   )
/// }
/// ```
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
///
/// Returns a response with `text/plain` content type.
/// Use for plain text output that isn't JSON, HTML, or another format.
///
/// ## Example
///
/// ### Text response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_text_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{text_response}
/// import dream/http/status.{ok}
///
/// pub fn healthcheck(_request, _context, _services) {
///   text_response(ok, "OK")
/// }
/// ```
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
///
/// Returns a response with `application/json` content type.
/// Pass a JSON string (from `gleam/json` or similar). This function
/// doesn't encode JSON for you—use `gleam/json` to encode first.
///
/// ## Example
///
/// ### JSON response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_json_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{json_response}
/// import dream/http/status.{ok}
/// import gleam/json
///
/// pub fn show_user(_request, _context, _services) {
///   let user_json =
///     json.object([
///       #("id", json.int(123)),
///       #("name", json.string("Alice")),
///     ])
///
///   json_response(ok, json.to_string(user_json))
/// }
/// ```
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
///
/// Returns a response with `text/html` content type.
/// Use for HTML pages, HTMX responses, or HTML fragments.
///
/// ## Example
///
/// ### HTML response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_html_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// pub fn index(_request, _context, _services) {
///   let html =
///     "
///     <!DOCTYPE html>
///     <html>
///       <body><h1>Welcome</h1></body>
///     </html>
///   "
///
///   response.html_response(status.ok, html)
/// }
/// ```
///
/// Guide: [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html).
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
///
/// Returns a redirect with the Location header set. Use with redirect
/// status codes (301, 302, 303, 307) to send the client to a new URL.
///
/// Common patterns:
/// - `303 See Other`: After POST/PUT/DELETE, redirect to GET (prevents duplicate submission)
/// - `302 Found`: Temporary redirect (can change method)
/// - `301 Moved Permanently`: Permanent redirect (update bookmarks/search engines)
///
/// ## Example
///
/// ### Redirect after a POST <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_redirect_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import gleam/int
///
/// pub fn create_post(_request, _context, _services) {
///   // After creating post, redirect to view it
///   let post_id = 123
///   response.redirect_response(
///     status.see_other,
///     "/posts/" <> int.to_string(post_id),
///   )
/// }
/// ```
///
/// Guide: [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
pub fn redirect_response(status: Int, location: String) -> Response {
  Response(
    status: status,
    body: Text(""),
    headers: [Header("Location", location)],
    cookies: [],
    content_type: option.None,
  )
}

/// Create an empty response with no body
///
/// Returns a response with no content. Commonly used with:
/// - `204 No Content`: Successful request with no data to return
/// - `404 Not Found`: Resource doesn't exist
///
/// ## Example
///
/// ### Empty response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_empty_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request, get_int_param}
/// import dream/http/response.{type Response}
/// import dream/http/status
///
/// pub type Services {
///   Services(delete_user: fn(Int) -> Nil)
/// }
///
/// pub fn delete_user(request: Request, _context, services: Services) -> Response {
///   case get_int_param(request, "id") {
///     Ok(user_id) -> {
///       // After successful deletion, return 204 with no body
///       services.delete_user(user_id)
///       response.empty_response(status.no_content)
///     }
///     Error(message) -> response.text_response(status.bad_request, message)
///   }
/// }
/// ```
pub fn empty_response(status: Int) -> Response {
  Response(
    status: status,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// Create a binary response for files, images, PDFs, etc.
///
/// Returns a response with binary data. Use for images, PDFs, zip files,
/// or any non-text content. You must specify the content type.
///
/// ## Example
///
/// ### Binary response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_binary_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import simplifile
///
/// pub fn serve_image(_request, _context, _services) {
///   case simplifile.read_bits("logo.png") {
///     Ok(image_data) ->
///       response.binary_response(status.ok, image_data, "image/png")
///     Error(_) -> response.empty_response(status.not_found)
///   }
/// }
/// ```
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
///
/// Returns a response with a stream of chunks. Use for:
/// - Large files (stream without loading entire file in memory)
/// - Real-time data (AI responses, logs, events)
/// - CSV exports (generate rows on-demand)
///
/// ## Example
///
/// ### Stream a CSV file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_stream_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import gleam/yielder
///
/// pub type Services {
///   Services(user_names: List(String))
/// }
///
/// pub fn export_users(_request, _context, services: Services) {
///   let user_stream =
///     services.user_names
///     |> yielder.from_list
///     |> yielder.map(user_to_csv_row)
///     |> yielder.map(fn(row) { <<row:utf8>> })
///
///   response.stream_response(status.ok, user_stream, "text/csv")
/// }
///
/// fn user_to_csv_row(name: String) -> String {
///   name <> "\n"
/// }
/// ```
///
/// Guide: [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html).
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

/// Create a Server-Sent Events (SSE) response.
///
/// **Deprecated:** This function uses chunked transfer encoding which stalls
/// after a few events because the yielder blocks in the mist handler process's
/// mailbox, competing with TCP messages. Use
/// `dream/servers/mist/sse.upgrade_to_sse` instead, which spawns a dedicated
/// OTP actor with its own mailbox. See the [SSE guide](docs/guides/sse.md)
/// for migration instructions.
///
/// Returns a streaming response configured for Server-Sent Events.
/// SSE enables server-to-client real-time updates over HTTP.
///
/// The response includes:
/// - `Content-Type: text/event-stream`
/// - `Cache-Control: no-cache`
/// - `Connection: keep-alive`
///
/// ## Example
///
/// ### Create an SSE response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_sse_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/response.{type Response, sse_response}
/// import dream/http/status.{ok}
/// import gleam/yielder
///
/// pub fn events() -> Response {
///   let stream = yielder.from_list([<<"data: hello\n\n":utf8>>])
///   // Headers: Content-Type: text/event-stream, Cache-Control: no-cache,
///   // Connection: keep-alive
///   sse_response(ok, stream, "text/event-stream")
/// }
/// ```
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
