//// HTTP requests and responses
////
//// Core HTTP types for Dream applications. For response builders and status codes,
//// see the dream_helpers module.
////
//// ## Path Parameters
////
//// Extract and convert path parameters from routes:
////
//// ```gleam
//// pub fn show_user(request: Request, _ctx, _services) -> Response {
////   let assert Ok(param) = get_param(request, "id")
////   case param.as_int {
////     Ok(id) -> // id is an Int
////     Error(_) -> Response(status: 400, body: Text("Invalid ID"), ...)
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
//// let assert Ok(param) = get_param(request, "id")
//// param.value  // "123"
//// param.format // Some("json")
//// param.as_int // Ok(123)
//// ```
////
//// Use this for content negotiation without query strings.
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
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
/// For typed status codes and response builders, use dream_helpers.
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
    [param, ..rest] ->
      case string.split(param, "=") {
        [key, value] ->
          case key == name {
            True -> option.Some(value)
            False -> get_query_param_recursive(rest, name)
          }
        _ -> get_query_param_recursive(rest, name)
      }
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
/// ## Examples
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123
/// let assert Ok(param) = get_param(request, "id")
/// param.value  // "123"
/// param.as_int // Ok(123)
/// ```
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123.json
/// let assert Ok(param) = get_param(request, "id")
/// param.value  // "123"
/// param.format // Some("json")
/// param.as_int // Ok(123)
/// ```
///
/// ```gleam
/// // Handle conversion errors
/// case get_param(request, "id") {
///   Ok(param) ->
///     case param.as_int {
///       Ok(id) -> show_user(id)
///       Error(_) -> bad_request_response("Invalid ID")
///     }
///   Error(msg) -> not_found_response()
/// }
/// ```
pub fn get_param(request: Request, name: String) -> Result(PathParam, String) {
  case list.key_find(request.params, name) {
    Ok(value) -> Ok(parse_path_param(value))
    Error(_) -> Error("Missing required path parameter: " <> name)
  }
}

/// Create a new request with updated params
pub fn set_params(
  request: Request,
  new_params: List(#(String, String)),
) -> Request {
  Request(..request, params: new_params)
}
