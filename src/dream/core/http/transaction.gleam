//// HTTP transaction types and utilities for Dream web framework
////
//// This module provides core types for HTTP requests and responses,
//// including methods, headers, cookies, and utility functions for
//// working with HTTP transactions.

import dream/core/http/statuses.{type Status}
import gleam/list
import gleam/option
import gleam/string

/// HTTP method type
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

/// HTTP response type
pub type Response {
  Response(
    status: Status,
    body: String,
    headers: List(Header),
    cookies: List(Cookie),
    content_type: option.Option(String),
    content_length: option.Option(Int),
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

/// Create a secure cookie with httpOnly flag
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

/// Set or replace a header value
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

// Response builders

/// Create a simple text response
pub fn text_response(status: Status, body: String) -> Response {
  Response(
    status: status,
    body: body,
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
    content_length: option.Some(string.length(body)),
  )
}

/// Create a JSON response
pub fn json_response(status: Status, body: String) -> Response {
  Response(
    status: status,
    body: body,
    headers: [Header("Content-Type", "application/json; charset=utf-8")],
    cookies: [],
    content_type: option.Some("application/json; charset=utf-8"),
    content_length: option.Some(string.length(body)),
  )
}

/// Create an HTML response
pub fn html_response(status: Status, body: String) -> Response {
  Response(
    status: status,
    body: body,
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
    content_length: option.Some(string.length(body)),
  )
}

/// Create a redirect response
pub fn redirect_response(status: Status, location: String) -> Response {
  Response(
    status: status,
    body: "",
    headers: [Header("Location", location)],
    cookies: [],
    content_type: option.None,
    content_length: option.Some(0),
  )
}

/// Create an empty response (useful for status-only responses)
pub fn empty_response(status: Status) -> Response {
  Response(
    status: status,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.Some(0),
  )
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

/// Get a path parameter value by name
pub fn get_param(request: Request, name: String) -> Result(String, String) {
  case list.key_find(request.params, name) {
    Ok(value) -> Ok(value)
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
