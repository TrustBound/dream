//// HTTP response types and builders
////
//// Core response types and convenient functions for building common HTTP responses.
//// This module provides builders for text, JSON, HTML, binary, and streaming responses.
////
//// ## Quick Examples
////
//// ```gleam
//// import dream/http/response
//// import dream/http/status
////
//// // Text response
//// response.text_response(status.ok, "Hello, World!")
////
//// // JSON response
//// response.json_response(status.ok, json.to_string(user_json))
////
//// // HTML response
//// response.html_response(status.ok, "<h1>Welcome</h1>")
////
//// // Redirect
//// response.redirect_response(status.see_other, "/login")
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
/// ```gleam
/// // Text responses (most common)
/// Text("Hello, World!")
/// Text(json.to_string(data))
///
/// // Binary response
/// Bytes(image_data)
///
/// // Streaming response
/// Stream(file_chunks)
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
/// - `cookies`: List of cookies to set
/// - `content_type`: Content-Type header value (automatically set by builders)
///
/// ## Example
///
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// // Using builder (recommended)
/// response.json_response(status.ok, user_json)
///
/// // Constructing directly (not recommended)
/// Response(
///   status: 200,
///   body: Text(user_json),
///   headers: [Header("Content-Type", "application/json")],
///   cookies: [],
///   content_type: Some("application/json")
/// )
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// pub fn healthcheck(request, context, services) {
///   response.text_response(status.ok, "OK")
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import gleam/json
///
/// pub fn show_user(request, context, services) {
///   let user_json = json.object([
///     #("id", json.int(123)),
///     #("name", json.string("Alice")),
///   ])
///   
///   response.json_response(status.ok, json.to_string(user_json))
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// pub fn index(request, context, services) {
///   let html = "
///     <!DOCTYPE html>
///     <html>
///       <body><h1>Welcome</h1></body>
///     </html>
///   "
///   
///   response.html_response(status.ok, html)
/// }
/// ```
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// pub fn create_post(request, context, services) {
///   // After creating post, redirect to view it
///   let post_id = 123
///   response.redirect_response(
///     status.see_other,
///     "/posts/" <> int.to_string(post_id)
///   )
/// }
/// ```
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
///
/// pub fn delete_user(request, context, services) {
///   // After successful deletion, return 204 with no body
///   delete_from_db(services.db, user_id)
///   response.empty_response(status.no_content)
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import simplifile
///
/// pub fn serve_image(request, context, services) {
///   case simplifile.read_bits("logo.png") {
///     Ok(image_data) ->
///       response.binary_response(status.ok, image_data, "image/png")
///     Error(_) ->
///       response.empty_response(status.not_found)
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import gleam/yielder
///
/// pub fn export_users(request, context, services) {
///   let user_stream = 
///     query_all_users(services.db)
///     |> yielder.from_list
///     |> yielder.map(user_to_csv_row)
///     |> yielder.map(fn(row) { <<row:utf8>> })
///   
///   response.stream_response(status.ok, user_stream, "text/csv")
/// }
/// ```
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
/// ```gleam
/// import dream/http/response
/// import dream/http/status
/// import gleam/yielder
///
/// pub fn events(request, context, services) {
///   let event_stream = 
///     subscribe_to_events(services)
///     |> yielder.map(format_sse_event)
///   
///   response.sse_response(status.ok, event_stream, "text/event-stream")
/// }
///
/// fn format_sse_event(data: String) -> BitArray {
///   <<"data: ", data:utf8, "\n\n":utf8>>
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
