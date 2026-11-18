//// Example for the doc of `error.to_status_code`.

import dream/http/error.{NotFound}
import dream/http/response.{type Response}
import gleam/json

pub fn not_found_response() -> Response {
  let not_found = NotFound("User not found")
  // Returns 404
  let status = error.to_status_code(not_found)
  let error_json =
    json.object([#("error", json.string(error.message(not_found)))])
  response.json_response(status, json.to_string(error_json))
}
