//// Stream view - presentation logic for streaming example
////
//// This module handles all presentation concerns for the streaming example,
//// converting data into HTTP responses.

import dream_helpers/statuses.{internal_server_error_status, ok_status}
import dream/core/http/transaction.{type Response}
import dream_helpers/http.{text_response}

/// Respond with index/welcome message
pub fn respond_index() -> Response {
  text_response(
    ok_status(),
    "Streaming Example Server\n\n"
      <> "Routes:\n"
      <> "  GET /stream - Stream a response from httpbin.org\n"
      <> "  GET /fetch - Fetch and return a response from httpbin.org\n",
  )
}

/// Respond with streamed response
pub fn respond_stream(body: String) -> Response {
  text_response(ok_status(), "Streamed response:\n\n" <> body)
}

/// Respond with fetched response
pub fn respond_fetch(body: String) -> Response {
  text_response(ok_status(), "Fetched response:\n\n" <> body)
}

/// Respond with error message
pub fn respond_error(error: String) -> Response {
  text_response(internal_server_error_status(), "Error: " <> error)
}

