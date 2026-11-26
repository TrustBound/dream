//// Response helper utilities
////
//// Common helpers for handling responses in controllers, and the mapping
//// of the data errors of the models to Dream errors.

import dream/http.{type Error, type Response}
import dream/http/error
import dream_postgres/client
import gleam/list
import views/errors

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
    error.ServiceUnavailable(msg) -> errors.service_unavailable(msg)
    error.GatewayTimeout(msg) -> errors.gateway_timeout(msg)
  }
}

/// Turn the error of a generated model function into a Dream error.
///
/// The model gives data: `NotFound`, `Conflict` with the name of a unique
/// constraint, or `QueryFailed`. This function gives the text for the
/// client. `not_found` is the text of a missing row. `conflicts` gives the
/// text of each unique constraint of the `-- unique:` hints. A conflict
/// with no text, and a failed query, give an internal server error.
pub fn model_error_to_error(
  model_error: client.ModelQueryError,
  not_found not_found: String,
  conflicts conflicts: List(#(String, String)),
) -> Error {
  case model_error {
    client.NotFound -> error.NotFound(not_found)
    client.Conflict(constraint:) ->
      case list.key_find(conflicts, constraint) {
        Ok(message) -> error.Conflict(message)
        Error(Nil) ->
          error.InternalServerError("no conflict text for " <> constraint)
      }
    client.QueryFailed(message:, cause: _) -> error.InternalServerError(message)
  }
}
