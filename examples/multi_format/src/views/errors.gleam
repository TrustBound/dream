//// Shared error responses
////
//// Generic error responses used across the application.

import dream/http/response.{type Response, html_response}
import dream/http/status

/// 404 Not Found response
pub fn not_found(message: String) -> Response {
  html_response(
    status.not_found,
    "<h1>404 Not Found</h1><p>" <> message <> "</p>",
  )
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  html_response(
    status.internal_server_error,
    "<h1>500 Internal Server Error</h1>",
  )
}

/// 400 Bad Request response
pub fn bad_request() -> Response {
  html_response(status.bad_request, "<h1>400 Bad Request</h1>")
}
