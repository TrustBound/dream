//// Response helper utilities
////
//// Common helpers for handling responses in controllers.

import dream/http.{type Error, type Response}
import dream/http/error
import dream/http/response.{text_response}
import dream/http/status

/// Handle Dream errors and convert to appropriate HTTP responses
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) ->
      text_response(status.bad_request, "Bad Request: " <> msg)
    error.Unauthorized(_msg) ->
      text_response(status.unauthorized, "Unauthorized")
    error.Forbidden(_msg) -> text_response(status.forbidden, "Forbidden")
    error.NotFound(msg) -> text_response(status.not_found, "Not Found: " <> msg)
    error.UnprocessableContent(msg) ->
      text_response(status.unprocessable_content, "Unprocessable: " <> msg)
    error.InternalServerError(_msg) ->
      text_response(status.internal_server_error, "Internal Server Error")
  }
}
