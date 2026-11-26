//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error.{GatewayTimeout, ServiceUnavailable}
import views/errors.{gateway_timeout, service_unavailable}

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(_msg) -> errors.bad_request()
    error.Unauthorized(msg) -> errors.unauthorized(msg)
    error.Forbidden(msg) -> errors.forbidden(msg)
    error.NotFound(msg) -> errors.not_found(msg)
    error.Conflict(msg) -> errors.conflict(msg)
    error.UnprocessableContent(msg) -> errors.unprocessable_content(msg)
    error.InternalServerError(_msg) -> errors.internal_error()
    ServiceUnavailable(msg) -> service_unavailable(msg)
    GatewayTimeout(msg) -> gateway_timeout(msg)
  }
}
