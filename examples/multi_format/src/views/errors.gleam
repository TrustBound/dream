//// Shared error responses
////
//// Generic error responses used across the application.

import dream/http/response.{type Response, html_response}
import dream/http/status.{internal_server_error}

/// 404 Not Found response
pub fn not_found(message: String) -> Response {
  html_response(
    status.not_found,
    "<h1>404 Not Found</h1><p>" <> message <> "</p>",
  )
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  html_response(internal_server_error, "<h1>500 Internal Server Error</h1>")
}

/// 400 Bad Request response
pub fn bad_request() -> Response {
  html_response(status.bad_request, "<h1>400 Bad Request</h1>")
}

/// 401 Unauthorized response
pub fn unauthorized(message: String) -> Response {
  html_response(
    status.unauthorized,
    "<h1>401 Unauthorized</h1><p>" <> message <> "</p>",
  )
}

/// 403 Forbidden response
pub fn forbidden(message: String) -> Response {
  html_response(
    status.forbidden,
    "<h1>403 Forbidden</h1><p>" <> message <> "</p>",
  )
}

/// 422 Unprocessable Content response
pub fn unprocessable_content(message: String) -> Response {
  html_response(
    status.unprocessable_content,
    "<h1>422 Unprocessable Content</h1><p>" <> message <> "</p>",
  )
}

/// 409 Conflict response
pub fn conflict(message: String) -> Response {
  html_response(
    status.conflict,
    "<h1>409 Conflict</h1><p>" <> message <> "</p>",
  )
}

/// 503 Service Unavailable response
pub fn service_unavailable(message: String) -> Response {
  html_response(
    status.service_unavailable,
    "<h1>503 Service Unavailable</h1><p>" <> message <> "</p>",
  )
}

/// 504 Gateway Timeout response
pub fn gateway_timeout(message: String) -> Response {
  html_response(
    status.gateway_timeout,
    "<h1>504 Gateway Timeout</h1><p>" <> message <> "</p>",
  )
}
