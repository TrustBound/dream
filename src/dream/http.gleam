//// Convenience module for HTTP utilities
////
//// This module re-exports all HTTP-related types and functions from the
//// dream/http submodules, allowing you to use a single import in your controllers.
////
//// Instead of importing from multiple modules:
////
//// ### Import each module <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_separate_imports.gleam#L1-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
//// ### Import dream/http <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_single_import.gleam#L1-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
//// - `Request`, `Response`, `Method`, `Protocol`, `Version`
//// - `Header`, `Cookie`, `SameSite`, `PathParam`
//// - `ResponseBody`, `Error`
////
//// **Functions:**
//// - Response builders: `text_response`, `json_response`, `html_response`, etc.
//// - Status codes: `ok`, `created`, `bad_request`, `not_found`, etc.
//// - Parameter validation: `require_int`, `require_string`, `require_form`, etc.
//// - Header utilities: `get_header`, `header_name` and `header_value`. Import `dream/http/header` for `set_header`, `add_header` and `remove_header`.
//// - Cookie utilities: `get_cookie`, `simple_cookie`, `secure_cookie`, etc.
//// - Request utilities: `get_param`, `get_query_param`, `has_content_type`, etc.
////
//// ## When to Use This
////
//// Use `dream/http` in controllers for convenience. For more specific imports
//// or when you only need one or two functions, import the specific submodule:
////
//// ### Import one submodule <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_submodule_imports.gleam#L1-L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// // Just status codes
//// import dream/http/status
////
//// // Just error type
//// import dream/http/error.{type Error}
//// ```

// Re-export request types and functions
pub type Request =
  request.Request

pub type Method =
  request.Method

pub type Protocol =
  request.Protocol

pub type Version =
  request.Version

pub type PathParam =
  request.PathParam

// Request functions
pub const method_to_string = request.method_to_string

pub const parse_method = request.parse_method

pub const get_query_param = request.get_query_param

pub const has_content_type = request.has_content_type

pub const is_method = request.is_method

pub const set_params = request.set_params

pub const get_param = request.get_param

pub const get_int_param = request.get_int_param

pub const get_string_param = request.get_string_param

// Re-export response types and functions
pub type Response =
  response.Response

pub type ResponseBody =
  response.ResponseBody

// ResponseBody constructors (re-export by importing qualified)

// Response functions
pub const text_response = response.text_response

pub const json_response = response.json_response

pub const html_response = response.html_response

pub const binary_response = response.binary_response

pub const stream_response = response.stream_response

pub const empty_response = response.empty_response

pub const redirect_response = response.redirect_response

// Re-export header types and functions
pub type Header =
  header.Header

// Header constructor (re-export by importing qualified)
pub const header_name = header.header_name

pub const header_value = header.header_value

pub const get_header = header.get_header

// Re-export cookie types and functions
pub type Cookie =
  cookie.Cookie

pub type SameSite =
  cookie.SameSite

// Cookie and SameSite constructors (re-export by importing qualified)

pub const cookie_name = cookie.cookie_name

pub const cookie_value = cookie.cookie_value

pub const simple_cookie = cookie.simple_cookie

pub const secure_cookie = cookie.secure_cookie

pub const get_cookie = cookie.get_cookie

pub const get_cookie_value = cookie.get_cookie_value

// Re-export status codes
pub const ok = status.ok

pub const created = status.created

pub const accepted = status.accepted

pub const no_content = status.no_content

pub const moved_permanently = status.moved_permanently

pub const found = status.found

pub const see_other = status.see_other

pub const temporary_redirect = status.temporary_redirect

pub const bad_request = status.bad_request

pub const unauthorized = status.unauthorized

pub const forbidden = status.forbidden

pub const not_found = status.not_found

pub const method_not_allowed = status.method_not_allowed

pub const conflict = status.conflict

pub const unprocessable_content = status.unprocessable_content

pub const too_many_requests = status.too_many_requests

pub const internal_server_error = status.internal_server_error

pub const not_implemented = status.not_implemented

pub const service_unavailable = status.service_unavailable

// Re-export unified error type
pub type Error =
  error.Error

// Re-export params functions
pub const require_int = params.require_int

pub const require_string = params.require_string

pub const require_form = params.require_form

pub const require_field = params.require_field

pub const require_field_int = params.require_field_int

pub const field_optional = params.field_optional

// Re-export validation functions
pub const validate_json = validation.validate_json

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
