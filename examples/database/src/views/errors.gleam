//// Shared error responses
////
//// Generic error responses used across the application.
//// Views handle domain-specific formatting, this handles common HTTP errors.

import dream/http/response.{type Response, json_response}
import dream/http/status

/// 404 Not Found response
pub fn not_found(message: String) -> Response {
  json_response(status.not_found, "{\"error\": \"" <> message <> "\"}")
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  json_response(
    status.internal_server_error,
    "{\"error\": \"Internal server error\"}",
  )
}

/// 400 Bad Request response
pub fn bad_request(message: String) -> Response {
  json_response(status.bad_request, "{\"error\": \"" <> message <> "\"}")
}
