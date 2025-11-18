//// HTTP request types and utilities
////
//// Core request types and functions for working with HTTP requests in Dream.
//// Includes request methods, path parameters, query parameters, and request inspection.

import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header}
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string

/// HTTP request methods
///
/// The standard HTTP methods your routes can handle. Use these in your router
/// to specify which method a route responds to.
pub type Method {
  Post
  Get
  Put
  Delete
  Patch
  Options
  Head
}

/// HTTP protocol type
pub type Protocol {
  Http
  Https
}

/// HTTP version type
pub type Version {
  Http1
  Http2
  Http3
}

/// HTTP request type
pub type Request {
  Request(
    method: Method,
    protocol: Protocol,
    version: Version,
    path: String,
    query: String,
    // Raw query string
    params: List(#(String, String)),
    // Path parameters extracted from route pattern
    host: option.Option(String),
    port: option.Option(Int),
    remote_address: option.Option(String),
    body: String,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: option.Option(String),
    content_length: option.Option(Int),
  )
}

/// Path parameter with automatic type conversion and format detection
///
/// When you extract a path parameter with `get_param()`, you get a PathParam that:
/// - Detects format extensions (e.g., "123.json" → value="123", format=Some("json"))
/// - Provides automatic conversions to Int and Float
/// - Keeps the raw value for custom parsing
///
/// This makes content negotiation and type conversion trivial.
pub type PathParam {
  PathParam(
    raw: String,
    value: String,
    format: option.Option(String),
    as_int: Result(Int, Nil),
    as_float: Result(Float, Nil),
  )
}

// Method conversion utilities

/// Convert Method to its string representation
pub fn method_to_string(method: Method) -> String {
  case method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Options -> "OPTIONS"
    Head -> "HEAD"
  }
}

/// Parse a string to Method (case-insensitive)
pub fn parse_method(str: String) -> option.Option(Method) {
  case string.lowercase(str) {
    "get" -> option.Some(Get)
    "post" -> option.Some(Post)
    "put" -> option.Some(Put)
    "delete" -> option.Some(Delete)
    "patch" -> option.Some(Patch)
    "options" -> option.Some(Options)
    "head" -> option.Some(Head)
    _ -> option.None
  }
}

// Request utilities

/// Get a query parameter value from the raw query string
/// Note: This is a simple implementation. For full URL parsing,
/// consider using a dedicated URL parsing library.
pub fn get_query_param(query: String, name: String) -> option.Option(String) {
  // Simple implementation - would need proper URL decoding in production
  get_query_param_recursive(string.split(query, "&"), name)
}

fn get_query_param_recursive(
  params: List(String),
  name: String,
) -> option.Option(String) {
  case params {
    [] -> option.None
    [param, ..rest] -> {
      let result = parse_query_pair(param, name)
      case result {
        option.Some(_) -> result
        option.None -> get_query_param_recursive(rest, name)
      }
    }
  }
}

fn parse_query_pair(param: String, name: String) -> option.Option(String) {
  case string.split(param, "=") {
    [key, value] -> match_query_key(key, name, value)
    _ -> option.None
  }
}

fn match_query_key(
  key: String,
  name: String,
  value: String,
) -> option.Option(String) {
  case key == name {
    True -> option.Some(value)
    False -> option.None
  }
}

/// Check if request has a specific content type
pub fn has_content_type(request: Request, content_type: String) -> Bool {
  case request.content_type {
    option.Some(actual_content_type) ->
      string.contains(actual_content_type, content_type)
    option.None -> False
  }
}

/// Check if request method matches
pub fn is_method(request: Request, method: Method) -> Bool {
  request.method == method
}

/// Create a new request with updated params
pub fn set_params(
  request: Request,
  new_params: List(#(String, String)),
) -> Request {
  Request(..request, params: new_params)
}

// Path parameter utilities

/// Parse a path parameter string into PathParam with format detection
fn parse_path_param(raw: String) -> PathParam {
  // Split on last dot to extract format extension
  let parts = string.split(raw, ".")
  let #(value, format) = extract_format(parts, raw)

  PathParam(
    raw: raw,
    value: value,
    format: format,
    as_int: int.parse(value),
    as_float: float.parse(value),
  )
}

fn extract_format(
  parts: List(String),
  raw: String,
) -> #(String, option.Option(String)) {
  case parts {
    [val, ext] -> #(val, option.Some(ext))
    _ -> #(raw, option.None)
  }
}

/// Extract a path parameter by name
///
/// Returns a `PathParam` with automatic type conversion and format detection.
/// If the parameter doesn't exist, returns an error message.
///
/// For common cases, use `get_int_param()` or `get_string_param()` instead,
/// which return `Result(Int, String)` or `Result(String, String)` with
/// custom error messages.
///
/// ## Examples
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123
/// case get_param(request, "id") {
///   Ok(param) -> {
///     param.value  // "123"
///     param.as_int // Ok(123)
///   }
///   Error(msg) -> // handle error
/// }
/// ```
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123.json
/// case get_param(request, "id") {
///   Ok(param) -> {
///     param.value  // "123"
///     param.format // Some("json")
///     param.as_int // Ok(123)
///   }
///   Error(msg) -> // handle error
/// }
/// ```
///
/// ```gleam
/// // For simple integer extraction, use get_int_param:
/// case get_int_param(request, "id") {
///   Ok(id) -> show_user(id)
///   Error(msg) -> json_response(status.bad_request, error_json(msg))
/// }
/// ```
pub fn get_param(request: Request, name: String) -> Result(PathParam, String) {
  case list.key_find(request.params, name) {
    Ok(value) -> Ok(parse_path_param(value))
    Error(_) -> Error("Missing required path parameter: " <> name)
  }
}

/// Extract a path parameter as an integer
///
/// Returns a Result with a custom error message if the parameter is missing
/// or cannot be converted to an integer.
///
/// ## Examples
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123
/// case get_int_param(request, "id") {
///   Ok(id) -> show_user(id)
///   Error(msg) -> json_response(status.bad_request, error_json(msg))
/// }
/// ```
pub fn get_int_param(request: Request, name: String) -> Result(Int, String) {
  case get_param(request, name) {
    Ok(param) -> param_to_int(param, name)
    Error(_) -> Error("Missing " <> name <> " parameter")
  }
}

fn param_to_int(param: PathParam, name: String) -> Result(Int, String) {
  case param.as_int {
    Ok(id) -> Ok(id)
    Error(_) -> Error(name <> " must be an integer")
  }
}

/// Extract a path parameter as a string
///
/// Returns a Result with a custom error message if the parameter is missing.
///
/// ## Examples
///
/// ```gleam
/// // Route: /users/:name
/// // Request: /users/john
/// case get_string_param(request, "name") {
///   Ok(name) -> show_user_by_name(name)
///   Error(msg) -> json_response(status.bad_request, error_json(msg))
/// }
/// ```
pub fn get_string_param(
  request: Request,
  name: String,
) -> Result(String, String) {
  case get_param(request, name) {
    Ok(param) -> param_to_string(param, name)
    Error(_) -> Error("Missing " <> name <> " parameter")
  }
}

fn param_to_string(param: PathParam, _name: String) -> Result(String, String) {
  Ok(param.value)
}



