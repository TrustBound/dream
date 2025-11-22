//// HTTP requests and responses
////
//// Core HTTP types for Dream applications. For response builders and status codes,
//// see the dream_json module.
////
//// ## Path Parameters
////
//// Extract and convert path parameters from routes:
////
//// ```gleam
//// pub fn show_user(request: Request, _ctx, _services) -> Response {
////   let result = get_int_param(request, "id")
////   
////   case result {
////     Ok(id) -> json_response(status.ok, user_to_json(id))
////     Error(msg) -> json_response(status.bad_request, error_json(msg))
////   }
//// }
//// ```
////
//// ## Format Detection
////
//// PathParam automatically detects format extensions:
////
//// ```gleam
//// // Request to /users/123.json
//// let result = get_param(request, "id")
//// 
//// case result {
////   Ok(param) -> {
////     // param.value is "123"
////     // param.format is Some("json")
////     // param.as_int is Ok(123)
////     use_param_data(param)
////   }
////   Error(msg) -> handle_param_error(msg)
//// }
//// ```
////
//// Use this for content negotiation without query strings.

import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import gleam/yielder

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

/// HTTP header type
pub type Header {
  Header(name: String, value: String)
}

/// SameSite cookie attribute
pub type SameSite {
  Strict
  Lax
  None
}

/// HTTP cookie type
pub type Cookie {
  Cookie(
    name: String,
    value: String,
    expires: option.Option(Int),
    // Unix timestamp
    max_age: option.Option(Int),
    // Seconds
    domain: option.Option(String),
    path: option.Option(String),
    secure: Bool,
    http_only: Bool,
    same_site: option.Option(SameSite),
  )
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

/// Response body types
///
/// Supports text, binary data, and streaming for different use cases:
/// - `Text` for JSON, HTML, plain text
/// - `Bytes` for images, PDFs, files
/// - `Stream` for large files, AI responses, real-time data
pub type ResponseBody {
  Text(String)
  Bytes(BitArray)
  Stream(yielder.Yielder(BitArray))
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

/// HTTP response type
///
/// The status field is an Int (HTTP status code like 200, 404, 500).
/// For JSON encoding utilities, use dream_json.
pub type Response {
  Response(
    status: Int,
    body: ResponseBody,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: option.Option(String),
  )
}

// Cookie constructors

/// Get the name of a cookie
pub fn cookie_name(cookie: Cookie) -> String {
  let Cookie(name, _, _, _, _, _, _, _, _) = cookie
  name
}

/// Get the value of a cookie
pub fn cookie_value(cookie: Cookie) -> String {
  let Cookie(_, value, _, _, _, _, _, _, _) = cookie
  value
}

/// Create a simple cookie with just name and value
///
/// Creates an unsecured cookie with no expiration. Use `secure_cookie()` for
/// sensitive data like sessions or authentication tokens.
pub fn simple_cookie(name: String, value: String) -> Cookie {
  Cookie(
    name: name,
    value: value,
    expires: option.None,
    max_age: option.None,
    domain: option.None,
    path: option.None,
    secure: False,
    http_only: False,
    same_site: option.None,
  )
}

/// Create a secure cookie for sensitive data
///
/// Sets `secure=True`, `httpOnly=True`, and `sameSite=Strict`. Use this for
/// session IDs, authentication tokens, or any sensitive data. The httpOnly flag
/// prevents JavaScript access, protecting against XSS attacks.
pub fn secure_cookie(name: String, value: String) -> Cookie {
  Cookie(
    name: name,
    value: value,
    expires: option.None,
    max_age: option.None,
    domain: option.None,
    path: option.None,
    secure: True,
    http_only: True,
    same_site: option.Some(Strict),
  )
}

// Header utilities

/// Get the name of a header
pub fn header_name(header: Header) -> String {
  case header {
    Header(name, _) -> name
  }
}

/// Get the value of a header
pub fn header_value(header: Header) -> String {
  case header {
    Header(_, value) -> value
  }
}

/// Get the value of a header by name (case-insensitive)
pub fn get_header(headers: List(Header), name: String) -> option.Option(String) {
  let normalized_name = string.lowercase(name)
  case headers {
    [] -> option.None
    [Header(header_name, value), ..rest] ->
      case string.lowercase(header_name) == normalized_name {
        True -> option.Some(value)
        False -> get_header(rest, name)
      }
  }
}

/// Set or replace a header
///
/// If the header exists, replaces its value. If not, adds it. Header names are
/// case-insensitive but you should use standard casing for compatibility.
///
/// ## Example
///
/// ```gleam
/// response.headers
/// |> set_header("Cache-Control", "max-age=3600")
/// |> set_header("X-Custom-Header", "value")
/// ```
pub fn set_header(
  headers: List(Header),
  name: String,
  value: String,
) -> List(Header) {
  let normalized_name = string.lowercase(name)
  let filtered =
    list.filter(headers, fn(header) {
      string.lowercase(header_name(header)) != normalized_name
    })
  [Header(name, value), ..filtered]
}

/// Add a header without removing existing ones with the same name
pub fn add_header(
  headers: List(Header),
  name: String,
  value: String,
) -> List(Header) {
  [Header(name, value), ..headers]
}

/// Remove a header by name (case-insensitive)
pub fn remove_header(headers: List(Header), name: String) -> List(Header) {
  let normalized_name = string.lowercase(name)
  list.filter(headers, fn(header) {
    string.lowercase(header_name(header)) != normalized_name
  })
}

// Cookie utilities

/// Get a cookie by name (case-insensitive)
pub fn get_cookie(cookies: List(Cookie), name: String) -> option.Option(Cookie) {
  let normalized_name = string.lowercase(name)
  case cookies {
    [] -> option.None
    [cookie, ..rest] ->
      case string.lowercase(cookie_name(cookie)) == normalized_name {
        True -> option.Some(cookie)
        False -> get_cookie(rest, name)
      }
  }
}

/// Get a cookie value by name
pub fn get_cookie_value(
  cookies: List(Cookie),
  name: String,
) -> option.Option(String) {
  case get_cookie(cookies, name) {
    option.Some(cookie) -> option.Some(cookie_value(cookie))
    option.None -> option.None
  }
}

/// Set or replace a cookie
pub fn set_cookie(cookies: List(Cookie), cookie: Cookie) -> List(Cookie) {
  let normalized_name = string.lowercase(cookie_name(cookie))
  let filtered =
    list.filter(cookies, fn(existing_cookie) {
      string.lowercase(cookie_name(existing_cookie)) != normalized_name
    })
  [cookie, ..filtered]
}

/// Remove a cookie by name
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie) {
  let normalized_name = string.lowercase(name)
  list.filter(cookies, fn(cookie) {
    string.lowercase(cookie_name(cookie)) != normalized_name
  })
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
/// 
/// Properly decodes URL-encoded values (e.g., %20 → space, %26 → &)
/// Returns None if the parameter is not found.
pub fn get_query_param(query: String, name: String) -> option.Option(String) {
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
    [key, value] -> {
      // Decode both key and value
      let decoded_key = decode_url_component(key)
      let decoded_value = decode_url_component(value)
      match_query_key(decoded_key, name, decoded_value)
    }
    [key] -> {
      // Parameter with no value (empty string)
      let decoded_key = decode_url_component(key)
      match_query_key(decoded_key, name, "")
    }
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

/// Decode a URL-encoded component (key or value)
/// 
/// Handles percent-encoded sequences (e.g., %20, %26) and plus signs (+ → space)
/// Falls back to original string if decoding fails
fn decode_url_component(component: String) -> String {
  // Replace + with space (form encoding convention)
  let with_spaces = string.replace(component, "+", " ")

  // Decode percent-encoded sequences
  case uri.percent_decode(with_spaces) {
    Ok(decoded) -> decoded
    Error(_) -> with_spaces
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

/// Parse a path parameter string into PathParam with format detection
fn parse_path_param(raw: String) -> PathParam {
  // Split on last dot to extract format extension
  let parts = string.split(raw, ".")
  let #(value, format) = case parts {
    [val, ext] -> #(val, option.Some(ext))
    _ -> #(raw, option.None)
  }

  PathParam(
    raw: raw,
    value: value,
    format: format,
    as_int: int.parse(value),
    as_float: float.parse(value),
  )
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

/// Create a new request with updated params
pub fn set_params(
  request: Request,
  new_params: List(#(String, String)),
) -> Request {
  Request(..request, params: new_params)
}
