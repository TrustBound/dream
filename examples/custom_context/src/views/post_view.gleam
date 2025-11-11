//// Post view - presentation logic for custom context example
////
//// This module handles all presentation concerns for the custom context example,
//// converting data into HTTP responses.

import dream/core/http/response.{text_response}
import dream/core/http/status
import dream/core/http/transaction.{type Response}

/// Respond with hello world message
pub fn respond_index() -> Response {
  text_response(status.ok, "Hello, World!")
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

  text_response(status.ok, body)
}

/// Respond with error message
pub fn respond_error(error: String) -> Response {
  text_response(status.internal_server_error, "Error: " <> error)
}
