//// Post view - presentation logic for simple example
////
//// This module handles all presentation concerns for the simple example,
//// converting data into HTTP responses.

import dream_helpers/statuses.{
  internal_server_error_status, ok_status,
}
import dream/core/http/transaction.{type Response}
import dream_helpers/http.{text_response}

/// Respond with hello world message
pub fn respond_index() -> Response {
  text_response(ok_status(), "Hello, World!")
}

/// Respond with user and post information along with HTTP response
pub fn respond_show(user: String, post: String, http_body: String) -> Response {
  let body =
    "User: "
    <> user
    <> ", Post: "
    <> post
    <> "\n\nHTTPS Response:\n\n"
    <> http_body

  text_response(ok_status(), body)
}

/// Respond with error message
pub fn respond_error(error: String) -> Response {
  text_response(internal_server_error_status(), "Error: " <> error)
}

