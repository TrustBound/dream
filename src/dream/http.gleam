//// Convenience module for HTTP utilities
////
//// Guides: [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) and [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
////
//// This module re-exports all HTTP-related types and functions from the
//// dream/http submodules, allowing you to use a single import in your controllers.
////
//// Instead of importing from multiple modules:
////
//// ### Import each module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_separate_imports.gleam#L1-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/params.{require_int}
//// import dream/http/request.{type Request}
//// import dream/http/response.{json_response}
//// import dream/http/status
//// ```
////
//// You can just import one:
////
//// ### Import dream/http <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_single_import.gleam#L1-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http
//// import gleam/json
////
//// pub fn show(request: http.Request, _context, _services) -> http.Response {
////   case http.require_int(request, "id") {
////     Ok(id) -> http.json_response(http.ok, user_to_json(id))
////     Error(_) -> http.json_response(http.bad_request, error_json())
////   }
//// }
//// ```
////
//// ## What's Re-exported
////
//// This module re-exports:
////
//// **Types:**
//// - `Request`, `RequestBody`, `BodyReadError`, `Response`, `Method`, `Protocol`, `Version`
//// - `Header`, `Cookie`, `SameSite`, `PathParam`
//// - `ResponseBody`, `Error`
////
//// **Functions:**
//// - Response builders: `text_response`, `json_response`, `html_response`, etc.
//// - Status codes: `ok`, `created`, `bad_request`, `not_found`, etc.
//// - Parameter validation: `require_int`, `require_string`, `require_form`, `require_json`, etc.
//// - Header utilities: `get_header`, `header_name` and `header_value`. Import `dream/http/header` for `set_header`, `add_header` and `remove_header`.
//// - Cookie utilities: `get_cookie`, `simple_cookie`, `secure_cookie`, etc.
//// - Request utilities: `get_param`, `get_query_param`, `has_content_type`, etc.
////
//// ## When to Use This
////
//// Use `dream/http` in controllers for convenience. For more specific imports
//// or when you only need one or two functions, import the specific submodule:
////
//// ### Import one submodule <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_submodule_imports.gleam#L1-L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// // Just status codes
//// import dream/http/status
////
//// // Just error type
//// import dream/http/error.{type Error}
//// ```

// Re-export request types and functions
/// The HTTP request type. Re-exported from `dream/http/request`.
pub type Request =
  request.Request

/// The HTTP request methods. Re-exported from `dream/http/request`.
pub type Method =
  request.Method

/// The HTTP protocol type: `Http` or `Https`. Re-exported from `dream/http/request`.
pub type Protocol =
  request.Protocol

/// The HTTP version type. Re-exported from `dream/http/request`.
pub type Version =
  request.Version

/// A path parameter with type conversions and format detection. Re-exported from `dream/http/request`.
pub type PathParam =
  request.PathParam

/// The body of a request. Re-exported from `dream/http/request`.
pub type RequestBody =
  request.RequestBody

/// Why a read of a streamed request body failed. Re-exported from `dream/http/request`.
pub type BodyReadError =
  request.BodyReadError

// Request functions
/// Converts a `Method` to its string form, for example `"GET"`. Re-exported from `dream/http/request`.
pub const method_to_string = request.method_to_string

/// Parses a method name, in any case, into a `Method`. Re-exported from `dream/http/request`.
pub const parse_method = request.parse_method

/// Gets a decoded query parameter value from a raw query string. Re-exported from `dream/http/request`.
pub const get_query_param = request.get_query_param

/// Checks if a request has a given content type. Re-exported from `dream/http/request`.
pub const has_content_type = request.has_content_type

/// Checks if a request has a given method. Re-exported from `dream/http/request`.
pub const is_method = request.is_method

/// Returns a copy of a request with new path parameters. Re-exported from `dream/http/request`.
pub const set_params = request.set_params

/// Gets a path parameter by name as a `PathParam`. Re-exported from `dream/http/request`.
pub const get_param = request.get_param

/// Gets a path parameter as an integer. Re-exported from `dream/http/request`.
pub const get_int_param = request.get_int_param

/// Gets a path parameter as a string. Re-exported from `dream/http/request`.
pub const get_string_param = request.get_string_param

// Re-export response types and functions
/// The HTTP response type. Re-exported from `dream/http/response`.
pub type Response =
  response.Response

/// The body of a response: `Text`, `Bytes` or `Stream`. Re-exported from `dream/http/response`.
pub type ResponseBody =
  response.ResponseBody

// ResponseBody constructors (re-export by importing qualified)

// Response functions
/// Creates a plain text response. Re-exported from `dream/http/response`.
pub const text_response = response.text_response

/// Creates a JSON response. Re-exported from `dream/http/response`.
pub const json_response = response.json_response

/// Creates an HTML response. Re-exported from `dream/http/response`.
pub const html_response = response.html_response

/// Creates a binary response, for files, images and PDFs. Re-exported from `dream/http/response`.
pub const binary_response = response.binary_response

/// Creates a streaming response. Re-exported from `dream/http/response`.
pub const stream_response = response.stream_response

/// Creates a response with no body. Re-exported from `dream/http/response`.
pub const empty_response = response.empty_response

/// Creates a redirect response. Re-exported from `dream/http/response`.
pub const redirect_response = response.redirect_response

// Re-export header types and functions
/// The HTTP header type. Re-exported from `dream/http/header`.
pub type Header =
  header.Header

// Header constructor (re-export by importing qualified)
/// Gets the name of a header. Re-exported from `dream/http/header`.
pub const header_name = header.header_name

/// Gets the value of a header. Re-exported from `dream/http/header`.
pub const header_value = header.header_value

/// Gets the value of a header by name. The name match ignores case. Re-exported from `dream/http/header`.
pub const get_header = header.get_header

// Re-export cookie types and functions
/// The HTTP cookie type. Re-exported from `dream/http/cookie`.
pub type Cookie =
  cookie.Cookie

/// The SameSite attribute of a cookie. Re-exported from `dream/http/cookie`.
pub type SameSite =
  cookie.SameSite

// Cookie and SameSite constructors (re-export by importing qualified)

/// Gets the name of a cookie. Re-exported from `dream/http/cookie`.
pub const cookie_name = cookie.cookie_name

/// Gets the value of a cookie. Re-exported from `dream/http/cookie`.
pub const cookie_value = cookie.cookie_value

/// Creates a cookie with only a name and a value. Re-exported from `dream/http/cookie`.
pub const simple_cookie = cookie.simple_cookie

/// Creates a secure cookie for sensitive data. Re-exported from `dream/http/cookie`.
pub const secure_cookie = cookie.secure_cookie

/// Gets a cookie by name. The name match ignores case. Re-exported from `dream/http/cookie`.
pub const get_cookie = cookie.get_cookie

/// Gets the value of a cookie by name. Re-exported from `dream/http/cookie`.
pub const get_cookie_value = cookie.get_cookie_value

// Re-export status codes
/// Status code 200 OK. Re-exported from `dream/http/status`.
pub const ok = status.ok

/// Status code 201 Created. Re-exported from `dream/http/status`.
pub const created = status.created

/// Status code 202 Accepted. Re-exported from `dream/http/status`.
pub const accepted = status.accepted

/// Status code 204 No Content. Re-exported from `dream/http/status`.
pub const no_content = status.no_content

/// Status code 301 Moved Permanently. Re-exported from `dream/http/status`.
pub const moved_permanently = status.moved_permanently

/// Status code 302 Found. Re-exported from `dream/http/status`.
pub const found = status.found

/// Status code 303 See Other. Re-exported from `dream/http/status`.
pub const see_other = status.see_other

/// Status code 307 Temporary Redirect. Re-exported from `dream/http/status`.
pub const temporary_redirect = status.temporary_redirect

/// Status code 400 Bad Request. Re-exported from `dream/http/status`.
pub const bad_request = status.bad_request

/// Status code 401 Unauthorized. Re-exported from `dream/http/status`.
pub const unauthorized = status.unauthorized

/// Status code 403 Forbidden. Re-exported from `dream/http/status`.
pub const forbidden = status.forbidden

/// Status code 404 Not Found. Re-exported from `dream/http/status`.
pub const not_found = status.not_found

/// Status code 405 Method Not Allowed. Re-exported from `dream/http/status`.
pub const method_not_allowed = status.method_not_allowed

/// Status code 409 Conflict. Re-exported from `dream/http/status`.
pub const conflict = status.conflict

/// Status code 422 Unprocessable Content. Re-exported from `dream/http/status`.
pub const unprocessable_content = status.unprocessable_content

/// Status code 429 Too Many Requests. Re-exported from `dream/http/status`.
pub const too_many_requests = status.too_many_requests

/// Status code 500 Internal Server Error. Re-exported from `dream/http/status`.
pub const internal_server_error = status.internal_server_error

/// Status code 501 Not Implemented. Re-exported from `dream/http/status`.
pub const not_implemented = status.not_implemented

/// Status code 503 Service Unavailable. Re-exported from `dream/http/status`.
pub const service_unavailable = status.service_unavailable

// Re-export unified error type
/// The error type for Dream applications. Re-exported from `dream/http/error`.
pub type Error =
  error.Error

// Re-export params functions
/// Gets a path parameter as an integer, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_int = params.require_int

/// Gets a path parameter as a string, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_string = params.require_string

/// Parses the form data in the request body, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_form = params.require_form

/// Decodes the JSON request body, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_json = params.require_json

/// Gets a field from form data, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_field = params.require_field

/// Gets a field from form data as an integer, or returns an `Error`. Re-exported from `dream/http/params`.
pub const require_field_int = params.require_field_int

/// Gets an optional field from form data. Re-exported from `dream/http/params`.
pub const field_optional = params.field_optional

// Re-export validation functions
/// Decodes a JSON string and reports every field error. Re-exported from `dream/http/validation`.
pub const validate_json = validation.validate_json

/// A validation error with details for each field. Re-exported from `dream/http/validation`.
pub type ValidationError =
  validation.ValidationError

// Import statements (at the end to avoid forward reference issues)
import dream/http/cookie
import dream/http/error
import dream/http/header
import dream/http/params
import dream/http/request
import dream/http/response
import dream/http/status
import dream/http/validation
