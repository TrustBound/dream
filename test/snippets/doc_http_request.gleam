//// Examples for the doc comments of `dream/http/request`.

import dream/http/request.{
  type Request, Http, Http1, Http2, Http3, Https, body_as_string, get_int_param,
  get_param, get_string_param, method_to_string,
}
import dream/http/response.{type Response, json_response, text_response}
import dream/http/status
import gleam/int
import gleam/json
import gleam/option.{type Option}

pub fn describe_protocol(request: Request) -> String {
  case request.protocol {
    Http -> "Insecure connection"
    Https -> "Secure connection"
  }
}

pub fn describe_version(request: Request) -> String {
  case request.version {
    Http1 -> "HTTP/1.1"
    Http2 -> "HTTP/2"
    Http3 -> "HTTP/3 (QUIC)"
  }
}

pub fn show_user(request: Request, _context, _services) -> Response {
  // Access request data
  let method = method_to_string(request.method)
  let path = request.path

  // Read the body as text and the path parameter as an Int
  case body_as_string(request), get_int_param(request, "id") {
    Ok(body), Ok(id) ->
      text_response(
        status.ok,
        method <> " " <> path <> " " <> int.to_string(id) <> " " <> body,
      )
    Error(Nil), _ ->
      text_response(status.bad_request, "Request body is not text")
    Ok(_body), Error(message) -> text_response(status.bad_request, message)
  }
}

pub fn show_body(request: Request, _context, _services) -> Response {
  case body_as_string(request) {
    Ok(body) -> text_response(status.ok, body)
    Error(_) -> text_response(status.bad_request, "Body is not valid UTF-8")
  }
}

// Route: /users/:id
// Request: /users/123
pub fn read_user_id(
  request: Request,
) -> Result(#(String, Result(Int, Nil)), String) {
  case get_param(request, "id") {
    // param.value is "123", param.as_int is Ok(123)
    Ok(param) -> Ok(#(param.value, param.as_int))
    Error(message) -> Error(message)
  }
}

// Route: /users/:id
// Request: /users/123.json
pub fn read_user_id_with_format(
  request: Request,
) -> Result(#(String, Option(String), Result(Int, Nil)), String) {
  case get_param(request, "id") {
    // param.value is "123", param.format is Some("json"), param.as_int is Ok(123)
    Ok(param) -> Ok(#(param.value, param.format, param.as_int))
    Error(message) -> Error(message)
  }
}

// Route: /users/:id
// Request: /users/123
pub fn show_user_by_id(request: Request, _context, _services) -> Response {
  case get_int_param(request, "id") {
    Ok(id) -> text_response(status.ok, "User " <> int.to_string(id))
    Error(message) -> json_response(status.bad_request, error_json(message))
  }
}

// Route: /users/:name
// Request: /users/john
pub fn show_user_by_name(request: Request, _context, _services) -> Response {
  case get_string_param(request, "name") {
    Ok(name) -> text_response(status.ok, "User " <> name)
    Error(message) -> json_response(status.bad_request, error_json(message))
  }
}

fn error_json(message: String) -> String {
  json.to_string(json.object([#("error", json.string(message))]))
}
