//// Naming conventions: Imports
////
//// Import the types, constructors and functions you use, and call them
//// bare. Keep a name qualified only when the bare name would clash. When
//// two imports offer the same name, qualify it on both sides.

import dream/http/error.{from_shared, message, to_status_code}
import dream/http/response.{type Response, text_response}
import dream_errors

pub fn not_found_response() -> Response {
  error_response(error.NotFound("User not found"))
}

pub fn error_response(failure: error.Error) -> Response {
  text_response(to_status_code(failure), message(failure))
}

pub fn error_response_qualified(failure: error.Error) -> response.Response {
  response.text_response(error.to_status_code(failure), error.message(failure))
}

pub fn shared_error_response(shared: dream_errors.Error(Nil)) -> Response {
  case shared {
    dream_errors.NotFound(..) -> not_found_with_message("User not found")
    other -> error_response(from_shared(other))
  }
}

pub fn not_found_with_message(message: String) -> Response {
  let failure = error.NotFound(message)
  text_response(to_status_code(failure), error.message(failure))
}
