//// Error response helpers

import dream/http/response.{type Response, json_response}
import dream/http/status
import gleam/json

pub fn not_found(message: String) -> Response {
  json_response(status.not_found, error_json(message))
}

pub fn bad_request(message: String) -> Response {
  json_response(status.bad_request, error_json(message))
}

pub fn internal_error() -> Response {
  json_response(
    status.internal_server_error,
    error_json("Internal server error"),
  )
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}

