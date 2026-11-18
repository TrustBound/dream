//// Examples for the docs of the `dream/http/transaction` parameter functions.

import dream/http/response.{type Response, json_response}
import dream/http/status
import dream/http/transaction.{
  type Request, get_int_param, get_param, get_string_param,
}
import gleam/json
import gleam/option.{type Option}

pub fn read_id(
  request: Request,
) -> Result(#(String, Result(Int, Nil)), String) {
  // Route: /users/:id
  // Request: /users/123
  case get_param(request, "id") {
    // #("123", Ok(123))
    Ok(param) -> Ok(#(param.value, param.as_int))
    Error(message) -> Error(message)
  }
}

pub fn read_id_with_format(
  request: Request,
) -> Result(#(String, Option(String), Result(Int, Nil)), String) {
  // Route: /users/:id
  // Request: /users/123.json
  case get_param(request, "id") {
    // #("123", Some("json"), Ok(123))
    Ok(param) -> Ok(#(param.value, param.format, param.as_int))
    Error(message) -> Error(message)
  }
}

pub fn show(request: Request) -> Response {
  // For simple integer extraction, use get_int_param:
  case get_int_param(request, "id") {
    Ok(id) -> show_user(id)
    Error(message) -> json_response(status.bad_request, error_json(message))
  }
}

pub fn show_by_id(request: Request) -> Response {
  // Route: /users/:id
  // Request: /users/123
  case get_int_param(request, "id") {
    Ok(id) -> show_user(id)
    Error(message) -> json_response(status.bad_request, error_json(message))
  }
}

pub fn show_by_name(request: Request) -> Response {
  // Route: /users/:name
  // Request: /users/john
  case get_string_param(request, "name") {
    Ok(name) -> show_user_by_name(name)
    Error(message) -> json_response(status.bad_request, error_json(message))
  }
}

fn show_user(id: Int) -> Response {
  json_response(status.ok, json.to_string(json.object([#("id", json.int(id))])))
}

fn show_user_by_name(name: String) -> Response {
  json_response(
    status.ok,
    json.to_string(json.object([#("name", json.string(name))])),
  )
}

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
