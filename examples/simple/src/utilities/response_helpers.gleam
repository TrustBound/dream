//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error.{
  BadRequest, Conflict, Forbidden, GatewayTimeout, InternalServerError, NotFound,
  ServiceUnavailable, Unauthorized, UnprocessableContent,
}
import dream/http/response.{text_response}
import dream/http/status.{
  bad_request, conflict, forbidden, gateway_timeout, internal_server_error,
  not_found, service_unavailable, unauthorized, unprocessable_content,
}

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    BadRequest(msg) -> text_response(bad_request, "Bad Request: " <> msg)
    Unauthorized(_msg) -> text_response(unauthorized, "Unauthorized")
    Forbidden(_msg) -> text_response(forbidden, "Forbidden")
    NotFound(msg) -> text_response(not_found, "Not Found: " <> msg)
    Conflict(msg) -> text_response(conflict, "Conflict: " <> msg)
    UnprocessableContent(msg) ->
      text_response(unprocessable_content, "Unprocessable: " <> msg)
    InternalServerError(_msg) ->
      text_response(internal_server_error, "Internal Server Error")
    ServiceUnavailable(_msg) ->
      text_response(service_unavailable, "Service Unavailable")
    GatewayTimeout(_msg) -> text_response(gateway_timeout, "Gateway Timeout")
  }
}
