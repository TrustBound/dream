//// HTTP request types and utilities
////
//// Core request types and functions for working with HTTP requests in Dream.
//// Includes request methods, path parameters, query parameters, and request inspection.
////
//// ## Quick Example
////
//// ### Show a user <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request_module.gleam#L1-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/request.{type Request, get_int_param}
//// import dream/http/response.{json_response, text_response}
//// import dream/http/status
//// import gleam/json
//// import gleam/result
////
//// pub fn show_user(request: Request, _context, services: Services) {
////   let result = {
////     use id <- result.try(get_int_param(request, "id"))
////     services.find_user(id)
////   }
////
////   case result {
////     Ok(user) -> json_response(status.ok, user_to_json(user))
////     Error(message) -> text_response(status.bad_request, message)
////   }
//// }
//// ```

import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header}
import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import gleam/yielder.{type Yielder}

/// HTTP request methods
///
/// The standard HTTP methods your routes can handle. Use these in your router
/// to specify which method a route responds to.
///
/// ## Example
///
/// ### Route by method <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request_methods.gleam#L2-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{Delete, Get, Post, Put}
/// import dream/router.{route, router}
///
/// pub fn user_router() {
///   router()
///   |> route(method: Get, path: "/users", controller: list_users, middleware: [])
///   |> route(
///     method: Post,
///     path: "/users",
///     controller: create_user,
///     middleware: [],
///   )
///   |> route(
///     method: Put,
///     path: "/users/:id",
///     controller: update_user,
///     middleware: [],
///   )
///   |> route(
///     method: Delete,
///     path: "/users/:id",
///     controller: delete_user,
///     middleware: [],
///   )
/// }
/// ```
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
///
/// Specifies whether the request came over HTTP or HTTPS.
///
/// ## Example
///
/// ### Check the protocol <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L13-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn describe_protocol(request: Request) -> String {
///   case request.protocol {
///     Http -> "Insecure connection"
///     Https -> "Secure connection"
///   }
/// }
/// ```
pub type Protocol {
  Http
  Https
}

/// HTTP version type
///
/// Specifies which HTTP protocol version was used.
/// Most requests will be Http1 (HTTP/1.1).
///
/// ## Example
///
/// ### Check the HTTP version <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L20-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn describe_version(request: Request) -> String {
///   case request.version {
///     Http1 -> "HTTP/1.1"
///     Http2 -> "HTTP/2"
///     Http3 -> "HTTP/3 (QUIC)"
///   }
/// }
/// ```
pub type Version {
  Http1
  Http2
  Http3
}

/// HTTP request type
///
/// Represents a complete HTTP request with all its data.
/// This is what your controllers receive as their first parameter.
///
/// ## Fields
///
/// - `method`: HTTP method (Get, Post, Put, etc.)
/// - `protocol`: HTTP or HTTPS
/// - `version`: HTTP version (Http1, Http2, Http3)
/// - `path`: Request path (e.g., "/users/123")
/// - `query`: Raw query string (e.g., "format=json&page=2")
/// - `params`: Path parameters extracted by router (e.g., [#("id", "123")])
/// - `host`: Host header value (e.g., "example.com")
/// - `port`: Port number (e.g., 443)
/// - `remote_address`: Client IP address
/// - `body`: Request body as a `RequestBody`: `Text` or `Bytes` on a normal
///   route, `Stream` on a route added with `stream_route`
/// - `headers`: List of HTTP headers
/// - `cookies`: List of cookies
/// - `content_type`: Content-Type header value
/// - `content_length`: Content-Length header value
///
/// ## Example
///
/// ### Read request data <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L28-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show_user(request: Request, _context, _services) -> Response {
///   // Access request data
///   let method = method_to_string(request.method)
///   let path = request.path
///
///   // Read the body as text and the path parameter as an Int
///   case body_as_string(request), get_int_param(request, "id") {
///     Ok(body), Ok(id) ->
///       text_response(
///         status.ok,
///         method <> " " <> path <> " " <> int.to_string(id) <> " " <> body,
///       )
///     Error(Nil), _ ->
///       text_response(status.bad_request, "Request body is not text")
///     Ok(_body), Error(message) -> text_response(status.bad_request, message)
///   }
/// }
/// ```
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
    body: RequestBody,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: option.Option(String),
    content_length: option.Option(Int),
  )
}

/// Request body
///
/// The body of a request, in the shape that the route gives it. A normal
/// route reads the whole body before the controller runs. A body that is
/// valid UTF-8 arrives as `Text`, and an empty body is `Text("")`. Any other
/// body arrives as `Bytes` with the exact bytes the client sent, so a binary
/// upload is never lost. A route added with `stream_route` does not read the
/// body first: the body arrives as `Stream`, and the controller reads the
/// chunks when it needs them.
///
/// The constructor names are the same as the names of `ResponseBody` in
/// `dream/http/response`, so a request and a response read the same way. In
/// a module that uses both, qualify one of them, for example `request.Text`.
///
/// ## Example
///
/// ### Measure the body <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request_body.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request, Bytes, Stream, Text}
/// import gleam/bit_array
/// import gleam/string
/// import gleam/yielder
///
/// pub fn body_size(request: Request) -> Int {
///   case request.body {
///     // A normal route, body is valid UTF-8
///     Text(text) -> string.byte_size(text)
///     // A normal route, body is not valid UTF-8
///     Bytes(bytes) -> bit_array.byte_size(bytes)
///     // A stream_route: add up the chunks as they arrive
///     Stream(chunks) -> yielder.fold(chunks, 0, add_chunk_size)
///   }
/// }
///
/// fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
///   total + bit_array.byte_size(chunk)
/// }
/// ```
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(BitArray))
}

/// Get the request body as a string
///
/// Gives the body as text for every body shape, so a controller that wants
/// text does not need to match on `RequestBody`. `Text` gives its string.
/// `Bytes` gives `Ok` only when the bytes are valid UTF-8. `Stream` reads
/// every chunk, joins them, and then converts the result, so the stream is
/// used up after this call. A body that is not valid UTF-8 gives
/// `Error(Nil)`.
///
/// ## Example
///
/// ### Read the body <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L46-L51"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show_body(request: Request, _context, _services) -> Response {
///   case body_as_string(request) {
///     Ok(body) -> text_response(status.ok, body)
///     Error(_) -> text_response(status.bad_request, "Body is not valid UTF-8")
///   }
/// }
/// ```
pub fn body_as_string(request: Request) -> Result(String, Nil) {
  case request.body {
    Text(text) -> Ok(text)
    Bytes(bytes) -> bit_array.to_string(bytes)
    Stream(chunks) ->
      chunks
      |> yielder.fold(<<>>, bit_array.append)
      |> bit_array.to_string
  }
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
pub fn parse_method(method_name: String) -> option.Option(Method) {
  case string.lowercase(method_name) {
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
  case string.split_once(param, "=") {
    Ok(#(key, value)) -> {
      // Split at the first "=" only, then decode both key and value
      let decoded_key = decode_url_component(key)
      let decoded_value = decode_url_component(value)
      match_query_key(decoded_key, name, decoded_value)
    }
    Error(Nil) -> {
      // Parameter with no value (empty string)
      let decoded_key = decode_url_component(param)
      match_query_key(decoded_key, name, "")
    }
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
    [base_value, extension] -> #(base_value, option.Some(extension))
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
/// ### Read a path parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L53-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123
/// pub fn read_user_id(
///   request: Request,
/// ) -> Result(#(String, Result(Int, Nil)), String) {
///   case get_param(request, "id") {
///     // param.value is "123", param.as_int is Ok(123)
///     Ok(param) -> Ok(#(param.value, param.as_int))
///     Error(message) -> Error(message)
///   }
/// }
/// ```
///
/// ### Read a format extension <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L65-L75"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123.json
/// pub fn read_user_id_with_format(
///   request: Request,
/// ) -> Result(#(String, Option(String), Result(Int, Nil)), String) {
///   case get_param(request, "id") {
///     // param.value is "123", param.format is Some("json"), param.as_int is Ok(123)
///     Ok(param) -> Ok(#(param.value, param.format, param.as_int))
///     Error(message) -> Error(message)
///   }
/// }
/// ```
///
/// ### Read an integer parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L79-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show_user_by_id(request: Request, _context, _services) -> Response {
///   case get_int_param(request, "id") {
///     Ok(id) -> text_response(status.ok, "User " <> int.to_string(id))
///     Error(message) -> json_response(status.bad_request, error_json(message))
///   }
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
/// ### Show a user by ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L77-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Route: /users/:id
/// // Request: /users/123
/// pub fn show_user_by_id(request: Request, _context, _services) -> Response {
///   case get_int_param(request, "id") {
///     Ok(id) -> text_response(status.ok, "User " <> int.to_string(id))
///     Error(message) -> json_response(status.bad_request, error_json(message))
///   }
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
/// ### Show a user by name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L86-L93"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Route: /users/:name
/// // Request: /users/john
/// pub fn show_user_by_name(request: Request, _context, _services) -> Response {
///   case get_string_param(request, "name") {
///     Ok(name) -> text_response(status.ok, "User " <> name)
///     Error(message) -> json_response(status.bad_request, error_json(message))
///   }
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
