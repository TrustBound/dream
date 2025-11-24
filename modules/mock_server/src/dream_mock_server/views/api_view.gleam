//// api_view.gleam - Presentation logic for API endpoints
////
//// Pure formatting functions: Request data → String
//// No Result types, no Response types, no error handling.

import gleam/json

/// Format GET request info as JSON string
pub fn get_to_json(path: String) -> String {
  get_to_json_object(path)
  |> json.to_string()
}

/// Format POST request info as JSON string
pub fn post_to_json(path: String, body: String) -> String {
  post_to_json_object(path, body)
  |> json.to_string()
}

/// Format PUT request info as JSON string
pub fn put_to_json(path: String, body: String) -> String {
  put_to_json_object(path, body)
  |> json.to_string()
}

/// Format DELETE request info as JSON string
pub fn delete_to_json(path: String) -> String {
  delete_to_json_object(path)
  |> json.to_string()
}

/// Format status code response as JSON string
pub fn status_to_json(code: Int) -> String {
  status_to_json_object(code)
  |> json.to_string()
}

/// Format simple JSON response
pub fn simple_json_to_string() -> String {
  simple_json_object()
  |> json.to_string()
}

/// Format UUID response as JSON string
pub fn uuid_to_json() -> String {
  uuid_json_object()
  |> json.to_string()
}

/// Format plain text response
pub fn text_to_string() -> String {
  "Hello, World!"
}

/// Format error message as JSON string
pub fn error_to_json(message: String) -> String {
  error_to_json_object(message)
  |> json.to_string()
}

// Private helpers - all named functions

fn get_to_json_object(path: String) -> json.Json {
  json.object([
    #("method", json.string("GET")),
    #("url", json.string(path)),
    #("headers", json.array(from: [], of: json.string)),
  ])
}

fn post_to_json_object(path: String, body: String) -> json.Json {
  json.object([
    #("method", json.string("POST")),
    #("url", json.string(path)),
    #("data", json.string(body)),
  ])
}

fn put_to_json_object(path: String, body: String) -> json.Json {
  json.object([
    #("method", json.string("PUT")),
    #("url", json.string(path)),
    #("data", json.string(body)),
  ])
}

fn delete_to_json_object(path: String) -> json.Json {
  json.object([
    #("method", json.string("DELETE")),
    #("url", json.string(path)),
  ])
}

fn status_to_json_object(code: Int) -> json.Json {
  json.object([
    #("status", json.int(code)),
  ])
}

fn simple_json_object() -> json.Json {
  json.object([
    #("message", json.string("Hello, World!")),
    #("success", json.bool(True)),
  ])
}

fn uuid_json_object() -> json.Json {
  let uuid_str = "123e4567-e89b-12d3-a456-426614174000"
  json.object([
    #("uuid", json.string(uuid_str)),
  ])
}

fn error_to_json_object(message: String) -> json.Json {
  json.object([
    #("error", json.string(message)),
  ])
}
