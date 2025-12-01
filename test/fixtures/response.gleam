//// Reusable response fixtures for tests.
////
//// Provides factory functions for creating test responses with sensible defaults.

import dream/http/header.{Header}
import dream/http/response.{type Response, Response, Text}
import gleam/option

/// Create a minimal OK response.
pub fn create_response(status: Int, body: String) -> Response {
  Response(
    status: status,
    body: Text(body),
    headers: [],
    cookies: [],
    content_type: option.None,
  )
}

/// Create a response with headers.
pub fn create_response_with_headers(
  status: Int,
  body: String,
  headers: List(header.Header),
) -> Response {
  Response(..create_response(status, body), headers: headers)
}

/// Create a JSON response.
pub fn create_json_response(status: Int, body: String) -> Response {
  Response(
    status: status,
    body: Text(body),
    headers: [Header("Content-Type", "application/json")],
    cookies: [],
    content_type: option.Some("application/json"),
  )
}
