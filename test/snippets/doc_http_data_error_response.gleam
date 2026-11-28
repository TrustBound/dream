//// Example for the module doc of `dream/http/error`: errors to responses.

import dream/http/error.{type Error, message, to_status_code}
import dream/http/response.{type Response, json_response}
import gleam/json

pub fn user_response(result: Result(String, Error)) -> Response {
  case result {
    Ok(name) -> json_response(200, user_to_json(name))
    Error(error) -> create_error_response(error)
  }
}

fn user_to_json(name: String) -> String {
  json.object([#("name", json.string(name))])
  |> json.to_string
}

fn create_error_response(error: Error) -> Response {
  let error_json = json.object([#("error", json.string(message(error)))])
  json_response(to_status_code(error), json.to_string(error_json))
}
