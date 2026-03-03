//// api_controller.gleam - Non-streaming API endpoints
////
//// Handles HTTP concerns: parsing, response building.
//// All formatting is delegated to the view layer.

import dream/context.{type EmptyContext}
import dream/http/header.{Header}
import dream/http/request.{type Request, get_int_param}
import dream/http/response.{type Response, json_response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import dream_mock_server/compression
import dream_mock_server/views/api_view
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/string

/// GET /get - Returns JSON with request info
pub fn get(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.get_to_json(request.path))
}

/// POST /post - Echoes request body as JSON
pub fn post(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(
    status.created,
    api_view.post_to_json(request.path, request.body),
  )
}

/// PUT /put - Echoes request body as JSON
pub fn put(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.put_to_json(request.path, request.body))
}

/// DELETE /delete - Returns success response
pub fn delete(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.delete_to_json(request.path))
}

/// GET /status/:code - Returns response with specified status code
pub fn status(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  case get_int_param(request, "code") {
    Ok(code) -> json_response(code, api_view.status_to_json(code))
    Error(error_msg) ->
      json_response(status.bad_request, api_view.error_to_json(error_msg))
  }
}

/// GET /json - Returns simple JSON object
pub fn json_endpoint(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.simple_json_to_string())
}

/// GET /text - Returns plain text
pub fn text(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, api_view.text_to_string())
}

/// GET /uuid - Returns a UUID-like string (simple version)
pub fn uuid(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  json_response(status.ok, api_view.uuid_to_json())
}

/// GET /large - Returns a very large response body (for memory testing)
pub fn large(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Generate ~1MB of text data
  let chunk = "This is a repeated line to create a large response body.\n"
  let repeated = string.repeat(chunk, 20_000)
  text_response(status.ok, repeated)
}

/// GET /empty - Returns empty response body
pub fn empty(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "")
}

/// GET /slow - Returns response after a long delay
pub fn slow(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Wait 5 seconds before responding
  process.sleep(5000)
  text_response(status.ok, "Slow response")
}

/// POST /content-type - Echoes the request Content-Type header value as plain text
pub fn content_type(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let content_type = option.unwrap(request.content_type, "")
  text_response(status.ok, content_type)
}

/// GET /gzip - Returns "Hello, World!" gzip-compressed
pub fn gzip(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let body = compression.gzip_compress(<<"Hello, World!":utf8>>)
  response.Response(
    status: status.ok,
    body: response.Bytes(body),
    headers: [
      Header("Content-Type", "text/plain"),
      Header("Content-Encoding", "gzip"),
    ],
    cookies: [],
    content_type: option.Some("text/plain"),
  )
}

/// GET /deflate - Returns "Hello, World!" deflate-compressed
pub fn deflate(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let body = compression.deflate_compress(<<"Hello, World!":utf8>>)
  response.Response(
    status: status.ok,
    body: response.Bytes(body),
    headers: [
      Header("Content-Type", "text/plain"),
      Header("Content-Encoding", "deflate"),
    ],
    cookies: [],
    content_type: option.Some("text/plain"),
  )
}

/// GET /identity - Returns "Hello, World!" with Content-Encoding: identity
pub fn identity(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  response.Response(
    status: status.ok,
    body: response.Text("Hello, World!"),
    headers: [
      Header("Content-Type", "text/plain; charset=utf-8"),
      Header("Content-Encoding", "identity"),
    ],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// GET /unknown-encoding - Returns raw bytes with Content-Encoding: br
pub fn unknown_encoding(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  response.Response(
    status: status.ok,
    body: response.Text("raw-uncompressed-bytes"),
    headers: [
      Header("Content-Type", "text/plain; charset=utf-8"),
      Header("Content-Encoding", "br"),
    ],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// GET /corrupted-gzip - Returns garbage bytes with Content-Encoding: gzip
pub fn corrupted_gzip(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  response.Response(
    status: status.ok,
    body: response.Bytes(<<"this is not valid gzip data at all":utf8>>),
    headers: [
      Header("Content-Type", "text/plain"),
      Header("Content-Encoding", "gzip"),
    ],
    cookies: [],
    content_type: option.Some("text/plain"),
  )
}

/// GET /non-utf8-error - Returns HTTP 400 with a body containing non-UTF-8 bytes
///
/// The body is "Error: " followed by bytes 0xC0, 0xC1, 0xFE, 0xFF which are
/// invalid in UTF-8 encoding. Used to test that the HTTP client can handle
/// error responses whose bodies are not valid UTF-8.
pub fn non_utf8_error(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // "Error: " as ASCII + invalid UTF-8 bytes (0xC0, 0xC1, 0xFE, 0xFF)
  let body = <<69, 114, 114, 111, 114, 58, 32, 192, 193, 254, 255>>
  response.Response(
    status: status.bad_request,
    body: response.Bytes(body),
    headers: [Header("Content-Type", "text/plain")],
    cookies: [],
    content_type: option.Some("text/plain"),
  )
}

/// GET /echo-accept-encoding - Echoes the request's Accept-Encoding header
pub fn echo_accept_encoding(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let accept_encoding =
    list.find(request.headers, fn(h) {
      string.lowercase(h.name) == "accept-encoding"
    })
  let value = case accept_encoding {
    Ok(found) -> found.value
    Error(Nil) -> ""
  }
  text_response(status.ok, value)
}
