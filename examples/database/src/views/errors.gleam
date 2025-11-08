//// Shared error responses
////
//// Generic error responses used across the application.
//// Views handle domain-specific formatting, this handles common HTTP errors.

import dream/core/http/statuses.{
  bad_request_status, internal_server_error_status, not_found_status,
}
import dream/core/http/transaction.{type Response, json_response}

/// 404 Not Found response
pub fn not_found(message: String) -> Response {
  json_response(not_found_status(), "{\"error\": \"" <> message <> "\"}")
}

/// 500 Internal Server Error response
pub fn internal_error() -> Response {
  json_response(
    internal_server_error_status(),
    "{\"error\": \"Internal server error\"}",
  )
}

/// 400 Bad Request response
pub fn bad_request(message: String) -> Response {
  json_response(bad_request_status(), "{\"error\": \"" <> message <> "\"}")
}
