//// Shared error responses
////
//// Generic error responses used across the application.

import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, not_found_status,
}
import dream/core/http/transaction.{type Response, html_response}

/// 404 Not Found response
pub fn not_found() -> Response {
  html_response(not_found_status(), "<h1>404 Not Found</h1>")
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  html_response(
    internal_server_error_status(),
    "<h1>500 Internal Server Error</h1>",
  )
}

/// 400 Bad Request response
pub fn bad_request() -> Response {
  html_response(bad_request_status(), "<h1>400 Bad Request</h1>")
}

