//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error.{
  BadRequest, Conflict, Forbidden, GatewayTimeout, InternalServerError, NotFound,
  ServiceUnavailable, Unauthorized, UnprocessableContent,
}
import views/errors.{
  bad_request, conflict, forbidden, gateway_timeout, internal_error, not_found,
  service_unavailable, unauthorized, unprocessable_content,
}

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    BadRequest(_msg) -> bad_request()
    Unauthorized(msg) -> unauthorized(msg)
    Forbidden(msg) -> forbidden(msg)
    NotFound(msg) -> not_found(msg)
    Conflict(msg) -> conflict(msg)
    UnprocessableContent(msg) -> unprocessable_content(msg)
    InternalServerError(_msg) -> internal_error()
    ServiceUnavailable(msg) -> service_unavailable(msg)
    GatewayTimeout(msg) -> gateway_timeout(msg)
  }
}
