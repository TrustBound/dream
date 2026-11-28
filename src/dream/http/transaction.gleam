//// HTTP requests and responses
////
//// Guides: [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) and [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
////
//// Core HTTP types for Dream applications. For response builders and status codes,
//// see the `dream/http/response` and `dream/http/status` modules.
////
//// ## Path Parameters
////
//// Extract and convert path parameters from routes:
////
//// ### Read a path parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_path.gleam#L1-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/response.{type Response, json_response}
//// import dream/http/status.{bad_request, ok}
//// import dream/http/transaction.{type Request, get_int_param}
//// import gleam/json
////
//// pub fn show_user(request: Request, _context, _services) -> Response {
////   let result = get_int_param(request, "id")
////
////   case result {
////     Ok(id) -> json_response(ok, user_to_json(id))
////     Error(message) -> json_response(bad_request, error_json(message))
////   }
//// }
//// ```
////
//// ## Format Detection
////
//// PathParam automatically detects format extensions:
////
//// ### Detect the format <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_format.gleam#L1-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/transaction.{type PathParam, type Request, get_param}
//// import gleam/option
////
//// pub fn describe_id(request: Request) -> String {
////   // Request to /users/123.json
////   let result = get_param(request, "id")
////
////   case result {
////     Ok(param) -> {
////       // param.value is "123"
////       // param.format is Some("json")
////       // param.as_int is Ok(123)
////       use_param_data(param)
////     }
////     Error(message) -> handle_param_error(message)
////   }
//// }
//// ```
////
//// Use this for content negotiation without query strings.

import dream/http/request
import dream/internal/path_parameter
import gleam/float
import gleam/http
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import gleam/yielder

/// HTTP request methods
///
/// The nine standard methods each have a constructor. Every other method is
/// `Other`, with its name exactly as the client sent it. Method names are
/// case-sensitive (RFC 9110, section 9.1).
pub type Method {
  Post
  Get
  Put
  Delete
  Patch
  Options
  Head
  Connect
  Trace
  Other(String)
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
///
/// `body` is a `RequestBody` from `dream/http/request`: `Text` or `Bytes` on a
/// normal route, `Stream` on a streaming route. This module uses that type
/// instead of a copy, because its own `ResponseBody` already has constructors
/// named `Text`, `Bytes` and `Stream`, and one module cannot define the same
/// constructor name twice.
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
    body: request.RequestBody,
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
///
/// ## Example
///
/// ### Get the cookie name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_cookie_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{cookie_name, simple_cookie}
///
/// pub fn theme_cookie_name() -> String {
///   let cookie = simple_cookie("theme", "dark")
///   // "theme"
///   cookie_name(cookie)
/// }
/// ```
pub fn cookie_name(cookie: Cookie) -> String {
  let Cookie(name, _, _, _, _, _, _, _, _) = cookie
  name
}

/// Get the value of a cookie
///
/// ## Example
///
/// ### Get the cookie value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_cookie_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{cookie_value, simple_cookie}
///
/// pub fn theme_cookie_value() -> String {
///   let cookie = simple_cookie("theme", "dark")
///   // "dark"
///   cookie_value(cookie)
/// }
/// ```
pub fn cookie_value(cookie: Cookie) -> String {
  let Cookie(_, value, _, _, _, _, _, _, _) = cookie
  value
}

/// Create a simple cookie with just name and value
///
/// Creates an unsecured cookie with no expiration. Use `secure_cookie()` for
/// sensitive data like sessions or authentication tokens.
///
/// ## Example
///
/// ### Create a simple cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_simple_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Cookie, simple_cookie}
///
/// pub fn theme_cookie() -> Cookie {
///   // Not secure, not httpOnly, no SameSite, no expiry
///   simple_cookie("theme", "dark")
/// }
/// ```
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
///
/// ## Example
///
/// ### Create a secure cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_secure_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Cookie, secure_cookie}
///
/// pub fn session_cookie() -> Cookie {
///   // secure: True, http_only: True, same_site: Some(Strict)
///   secure_cookie("session_id", "abc123")
/// }
/// ```
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
///
/// ## Example
///
/// ### Get the header name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_header_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{Header, header_name}
///
/// pub fn content_type_name() -> String {
///   let header = Header("Content-Type", "text/html")
///   // "Content-Type"
///   header_name(header)
/// }
/// ```
pub fn header_name(header: Header) -> String {
  case header {
    Header(name, _) -> name
  }
}

/// Get the value of a header
///
/// ## Example
///
/// ### Get the header value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_header_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{Header, header_value}
///
/// pub fn content_type_value() -> String {
///   let header = Header("Content-Type", "text/html")
///   // "text/html"
///   header_value(header)
/// }
/// ```
pub fn header_value(header: Header) -> String {
  case header {
    Header(_, value) -> value
  }
}

/// Get the value of a header by name (case-insensitive)
///
/// ## Example
///
/// ### Find a header <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_get_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{Header, get_header}
/// import gleam/option.{type Option}
///
/// pub fn content_type() -> Option(String) {
///   let headers = [Header("Content-Type", "application/json")]
///   // The name match ignores case: Some("application/json")
///   get_header(headers, "content-type")
/// }
/// ```
pub fn get_header(
  headers: List(Header),
  name: String,
) -> option.Option(String) {
  let normalized_name = string.lowercase(name)
  get_header_recursive(headers, normalized_name)
}

/// Recursively search for a header by normalized name
fn get_header_recursive(
  headers: List(Header),
  normalized_name: String,
) -> option.Option(String) {
  case headers {
    [] -> option.None
    [Header(header_name, value), ..rest] -> {
      let header_normalized = string.lowercase(header_name)
      let matches = header_normalized == normalized_name
      case matches {
        True -> option.Some(value)
        False -> get_header_recursive(rest, normalized_name)
      }
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
/// ### Set headers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_set_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Header, type Response, set_header}
///
/// pub fn cache_headers(response: Response) -> List(Header) {
///   response.headers
///   |> set_header("Cache-Control", "max-age=3600")
///   |> set_header("X-Custom-Header", "value")
/// }
/// ```
pub fn set_header(
  headers: List(Header),
  name: String,
  value: String,
) -> List(Header) {
  let normalized_name = string.lowercase(name)
  let filtered = list.filter(headers, header_name_mismatch(normalized_name))
  [Header(name, value), ..filtered]
}

/// Check if a header's name doesn't match the normalized name
fn header_name_mismatch(normalized_name: String) -> fn(Header) -> Bool {
  fn(header) { string.lowercase(header_name(header)) != normalized_name }
}

/// Add a header without removing existing ones with the same name
///
/// ## Example
///
/// ### Add headers with the same name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_add_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Header, add_header}
///
/// pub fn set_cookie_headers() -> List(Header) {
///   // Both headers stay, the newest first:
///   // [Header("Set-Cookie", "b=2"), Header("Set-Cookie", "a=1")]
///   []
///   |> add_header("Set-Cookie", "a=1")
///   |> add_header("Set-Cookie", "b=2")
/// }
/// ```
pub fn add_header(
  headers: List(Header),
  name: String,
  value: String,
) -> List(Header) {
  [Header(name, value), ..headers]
}

/// Remove a header by name (case-insensitive)
///
/// ## Example
///
/// ### Remove a header <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_remove_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Header, Header, remove_header}
///
/// pub fn public_headers() -> List(Header) {
///   let headers = [
///     Header("Server", "dream"),
///     Header("Content-Type", "text/plain"),
///   ]
///   // The name match ignores case: [Header("Content-Type", "text/plain")]
///   remove_header(headers, "server")
/// }
/// ```
pub fn remove_header(headers: List(Header), name: String) -> List(Header) {
  let normalized_name = string.lowercase(name)
  list.filter(headers, header_name_mismatch(normalized_name))
}

// Cookie utilities

/// Get a cookie by name (case-insensitive)
///
/// ## Example
///
/// ### Find a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_get_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{
///   type Cookie, get_cookie, secure_cookie, simple_cookie,
/// }
/// import gleam/option.{type Option}
///
/// pub fn session() -> Option(Cookie) {
///   let cookies = [
///     simple_cookie("theme", "dark"),
///     secure_cookie("session_id", "abc123"),
///   ]
///   // The name match ignores case: Some(secure_cookie("session_id", "abc123"))
///   get_cookie(cookies, "SESSION_ID")
/// }
/// ```
pub fn get_cookie(
  cookies: List(Cookie),
  name: String,
) -> option.Option(Cookie) {
  let normalized_name = string.lowercase(name)
  get_cookie_recursive(cookies, normalized_name)
}

/// Recursively search for a cookie by normalized name
fn get_cookie_recursive(
  cookies: List(Cookie),
  normalized_name: String,
) -> option.Option(Cookie) {
  case cookies {
    [] -> option.None
    [cookie, ..rest] -> {
      let cookie_normalized = string.lowercase(cookie_name(cookie))
      let matches = cookie_normalized == normalized_name
      case matches {
        True -> option.Some(cookie)
        False -> get_cookie_recursive(rest, normalized_name)
      }
    }
  }
}

/// Get a cookie value by name
///
/// ## Example
///
/// ### Read a cookie value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_get_cookie_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{get_cookie_value, simple_cookie}
/// import gleam/option.{type Option}
///
/// pub fn theme() -> Option(String) {
///   let cookies = [simple_cookie("theme", "dark")]
///   // Some("dark")
///   get_cookie_value(cookies, "theme")
/// }
/// ```
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
///
/// ## Example
///
/// ### Replace a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_set_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Cookie, set_cookie, simple_cookie}
///
/// pub fn dark_theme() -> List(Cookie) {
///   let cookies = [simple_cookie("theme", "light")]
///   // The new cookie replaces the old one: [simple_cookie("theme", "dark")]
///   set_cookie(cookies, simple_cookie("theme", "dark"))
/// }
/// ```
pub fn set_cookie(cookies: List(Cookie), cookie: Cookie) -> List(Cookie) {
  let normalized_name = string.lowercase(cookie_name(cookie))
  let filtered = list.filter(cookies, cookie_name_mismatch(normalized_name))
  [cookie, ..filtered]
}

/// Remove a cookie by name
///
/// ## Example
///
/// ### Remove a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_remove_cookie.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Cookie, remove_cookie, simple_cookie}
///
/// pub fn without_theme() -> List(Cookie) {
///   let cookies = [simple_cookie("theme", "dark"), simple_cookie("lang", "en")]
///   // [simple_cookie("lang", "en")]
///   remove_cookie(cookies, "theme")
/// }
/// ```
pub fn remove_cookie(cookies: List(Cookie), name: String) -> List(Cookie) {
  let normalized_name = string.lowercase(name)
  list.filter(cookies, cookie_name_mismatch(normalized_name))
}

/// Check if a cookie's name doesn't match the normalized name
/// Returns a function that can be used with list.filter
fn cookie_name_mismatch(normalized_name: String) -> fn(Cookie) -> Bool {
  check_cookie_name_mismatch(normalized_name)
}

/// Check if a cookie's name doesn't match the normalized name
fn check_cookie_name_mismatch(normalized_name: String) -> fn(Cookie) -> Bool {
  fn(cookie) { string.lowercase(cookie_name(cookie)) != normalized_name }
}

// Method conversion utilities

/// Convert Method to its string representation
///
/// A standard method gives its upper-case name. `Other` gives its name
/// exactly as it is.
///
/// ## Example
///
/// ### Get the method name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_method_to_string.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{Post, method_to_string}
///
/// pub fn post_name() -> String {
///   // "POST"
///   method_to_string(Post)
/// }
/// ```
pub fn method_to_string(method: Method) -> String {
  case method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Options -> "OPTIONS"
    Head -> "HEAD"
    Connect -> "CONNECT"
    Trace -> "TRACE"
    Other(name) -> name
  }
}

/// Parse a string to Method (case-insensitive)
///
/// The match ignores case for the nine standard names. Another valid method
/// token gives `Some(Other(name))` with the name exactly as given. Text that
/// is not a method token, for example `"GET /"`, gives `None`.
///
/// ## Example
///
/// ### Parse a method name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_parse_method.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Method, parse_method}
/// import gleam/option.{type Option}
///
/// pub fn delete_method() -> Option(Method) {
///   // The match ignores case: Some(Delete)
///   parse_method("delete")
/// }
/// ```
pub fn parse_method(method_name: String) -> option.Option(Method) {
  case string.lowercase(method_name) {
    "get" -> option.Some(Get)
    "post" -> option.Some(Post)
    "put" -> option.Some(Put)
    "delete" -> option.Some(Delete)
    "patch" -> option.Some(Patch)
    "options" -> option.Some(Options)
    "head" -> option.Some(Head)
    "connect" -> option.Some(Connect)
    "trace" -> option.Some(Trace)
    _ -> parse_other_method(method_name)
  }
}

/// A valid method token that is no standard method name becomes `Other` with
/// the exact name. gleam/http checks the token rules of RFC 9110.
fn parse_other_method(method_name: String) -> option.Option(Method) {
  case http.parse_method(method_name) {
    Ok(_token) -> option.Some(Other(method_name))
    Error(Nil) -> option.None
  }
}

// Request utilities

/// Get a query parameter value from the raw query string
///
/// Properly decodes URL-encoded values (e.g., %20 → space, %26 → &)
/// Returns None if the parameter is not found.
///
/// ## Example
///
/// ### Read a query parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_get_query_param.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{get_query_param}
/// import gleam/option.{type Option}
///
/// pub fn search_term() -> Option(String) {
///   let query = "q=hello%20world&page=2"
///   // The value is decoded: Some("hello world")
///   get_query_param(query, "q")
/// }
/// ```
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
///
/// ## Example
///
/// ### Check for JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_has_content_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Request, has_content_type}
///
/// pub fn is_json(request: Request) -> Bool {
///   // True for "application/json; charset=utf-8"
///   has_content_type(request, "application/json")
/// }
/// ```
pub fn has_content_type(request: Request, content_type: String) -> Bool {
  case request.content_type {
    option.Some(actual_content_type) ->
      string.contains(actual_content_type, content_type)
    option.None -> False
  }
}

/// Check if request method matches
///
/// ## Example
///
/// ### Check for POST <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_is_method.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Request, Post, is_method}
///
/// pub fn is_post(request: Request) -> Bool {
///   // True only for a POST request
///   is_method(request, Post)
/// }
/// ```
pub fn is_method(request: Request, method: Method) -> Bool {
  request.method == method
}

/// Parse a path parameter string into PathParam with format detection
fn parse_path_param(raw: String) -> PathParam {
  // Split on last dot to extract format extension
  let parts = string.split(raw, ".")
  let #(value, format) = case parts {
    [base_value, extension] -> #(base_value, option.Some(extension))
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
/// If the parameter doesn't exist, returns
/// `Error("Missing required path parameter: <name>")`.
///
/// For common cases, use `get_int_param()` or `get_string_param()` instead,
/// which return `Result(Int, String)` or `Result(String, String)` with
/// custom error messages.
///
/// ## Examples
///
/// ### Read a parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_params.gleam#L11-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn read_id(
///   request: Request,
/// ) -> Result(#(String, Result(Int, Nil)), String) {
///   // Route: /users/:id
///   // Request: /users/123
///   case get_param(request, "id") {
///     // #("123", Ok(123))
///     Ok(param) -> Ok(#(param.value, param.as_int))
///     Error(message) -> Error(message)
///   }
/// }
/// ```
///
/// ### Read a parameter with a format <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_params.gleam#L23-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn read_id_with_format(
///   request: Request,
/// ) -> Result(#(String, Option(String), Result(Int, Nil)), String) {
///   // Route: /users/:id
///   // Request: /users/123.json
///   case get_param(request, "id") {
///     // #("123", Some("json"), Ok(123))
///     Ok(param) -> Ok(#(param.value, param.format, param.as_int))
///     Error(message) -> Error(message)
///   }
/// }
/// ```
///
/// ### Read an integer parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_params.gleam#L35-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show(request: Request) -> Response {
///   // For simple integer extraction, use get_int_param:
///   case get_int_param(request, "id") {
///     Ok(id) -> show_user(id)
///     Error(message) -> json_response(status.bad_request, error_json(message))
///   }
/// }
/// ```
pub fn get_param(request: Request, name: String) -> Result(PathParam, String) {
  path_parameter.find(request.params, name)
  |> result.map(parse_path_param)
}

/// Extract a path parameter as an integer
///
/// Returns `Error("Missing required path parameter: <name>")` when the route
/// has no such parameter, the same message as `get_param`, and
/// `Error("<name> must be an integer")` when the value is not an integer.
///
/// ## Examples
///
/// ### Show a user by ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_params.gleam#L43-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show_by_id(request: Request) -> Response {
///   // Route: /users/:id
///   // Request: /users/123
///   case get_int_param(request, "id") {
///     Ok(id) -> show_user(id)
///     Error(message) -> json_response(status.bad_request, error_json(message))
///   }
/// }
/// ```
pub fn get_int_param(request: Request, name: String) -> Result(Int, String) {
  case get_param(request, name) {
    Ok(param) -> param_to_int(param, name)
    Error(message) -> Error(message)
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
/// Returns `Error("Missing required path parameter: <name>")` when the route
/// has no such parameter, the same message as `get_param`.
///
/// ## Examples
///
/// ### Show a user by name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_params.gleam#L52-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn show_by_name(request: Request) -> Response {
///   // Route: /users/:name
///   // Request: /users/john
///   case get_string_param(request, "name") {
///     Ok(name) -> show_user_by_name(name)
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
    Error(message) -> Error(message)
  }
}

fn param_to_string(param: PathParam, _name: String) -> Result(String, String) {
  Ok(param.value)
}

/// Create a new request with updated params
///
/// ## Example
///
/// ### Set the path parameters <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_transaction_set_params.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/transaction.{type Request, set_params}
///
/// pub fn with_user_id(request: Request) -> Request {
///   // The new request has params [#("id", "42")]
///   set_params(request, [#("id", "42")])
/// }
/// ```
pub fn set_params(
  request: Request,
  new_params: List(#(String, String)),
) -> Request {
  Request(..request, params: new_params)
}
