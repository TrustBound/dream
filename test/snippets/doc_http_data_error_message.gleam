//// Example for the doc of `error.message`.

import dream/http/error.{BadRequest}
import gleam/json

pub fn bad_request_json() -> json.Json {
  let bad_request = BadRequest("Invalid email format")
  // Returns "Invalid email format"
  let error_message = error.message(bad_request)

  // Build JSON error response
  json.object([
    #("error", json.string(error_message)),
    #("status", json.int(error.to_status_code(bad_request))),
  ])
}
