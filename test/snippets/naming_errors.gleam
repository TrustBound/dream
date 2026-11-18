//// Naming conventions: Error Handling
////
//// `handle_{noun}_error` turns an error into a result or a response.
//// `recover_from_{noun}` tries to get back to normal work.

import dream/http.{type Response}
import gleam/json

pub type AuthError {
  MissingToken
  ExpiredToken
}

pub type FetchError {
  Timeout
  ConnectionRefused
}

pub fn handle_parse_error(_error: json.DecodeError) -> Response {
  http.text_response(http.bad_request, "The body is not valid JSON")
}

pub fn handle_auth_error(error: AuthError) -> Response {
  case error {
    MissingToken -> http.text_response(http.unauthorized, "Sign in first")
    ExpiredToken -> http.text_response(http.unauthorized, "Sign in again")
  }
}

pub fn recover_from_timeout(
  result: Result(String, FetchError),
  retry: fn() -> Result(String, FetchError),
) -> Result(String, FetchError) {
  case result {
    Error(Timeout) -> retry()
    _ -> result
  }
}

pub fn recover_from_connection_error(
  result: Result(String, FetchError),
  cached: String,
) -> Result(String, FetchError) {
  case result {
    Error(ConnectionRefused) -> Ok(cached)
    _ -> result
  }
}
