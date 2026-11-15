//// HTTP header types and utilities
////
//// Types and functions for working with HTTP headers. Headers can be used
//// with both requests and responses.
////
//// ## Common Operations
////
//// ### Work with headers <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_header_module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/header.{Header}
////
//// pub fn use_headers() {
////   // Create headers
////   let headers = [
////     Header("Content-Type", "application/json"),
////     Header("Cache-Control", "max-age=3600"),
////   ]
////
////   // Get a header value
////   let content_type = header.get_header(headers, "content-type")
////   // Some("application/json")
////
////   // Set or replace a header
////   let with_custom = header.set_header(headers, "X-Custom", "value")
////
////   // Add a header without replacing
////   let with_cookie = header.add_header(with_custom, "Set-Cookie", "session=abc")
////
////   #(content_type, with_cookie)
//// }
//// ```

import gleam/list
import gleam/option
import gleam/string

/// HTTP header type
///
/// Represents a single HTTP header with a name and value.
/// Header names are case-insensitive in HTTP but conventionally
/// use Title-Case (e.g., "Content-Type", "Cache-Control").
///
/// ## Example
///
/// ### Create headers <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_header_type.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{type Header, Header}
///
/// pub fn response_headers() -> List(Header) {
///   [
///     Header("Content-Type", "application/json"),
///     Header("Cache-Control", "no-cache"),
///     Header("X-Request-ID", "abc-123"),
///   ]
/// }
/// ```
pub type Header {
  Header(name: String, value: String)
}

/// Get the name of a header
///
/// Extracts the name field from a Header.
///
/// ## Example
///
/// ### Get the name <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_header_name.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
///
/// pub fn content_type_name() -> String {
///   let content_type = Header("Content-Type", "application/json")
///   header.header_name(content_type)
///   // "Content-Type"
/// }
/// ```
pub fn header_name(header: Header) -> String {
  case header {
    Header(name, _) -> name
  }
}

/// Get the value of a header
///
/// Extracts the value field from a Header.
///
/// ## Example
///
/// ### Get the value <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_header_value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
///
/// pub fn content_type_value() -> String {
///   let content_type = Header("Content-Type", "application/json")
///   header.header_value(content_type)
///   // "application/json"
/// }
/// ```
pub fn header_value(header: Header) -> String {
  case header {
    Header(_, value) -> value
  }
}

/// Get the value of a header by name (case-insensitive)
///
/// Searches a list of headers for one matching the given name.
/// Header name comparison is case-insensitive ("content-type" matches "Content-Type").
/// Returns the first matching header's value.
///
/// ## Example
///
/// ### Look up a header <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_get_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
///
/// pub fn look_up_headers() {
///   let headers = [
///     Header("Content-Type", "application/json"),
///     Header("Cache-Control", "max-age=3600"),
///   ]
///
///   let content_type = header.get_header(headers, "content-type")
///   // Some("application/json")
///   let cache_control = header.get_header(headers, "CACHE-CONTROL")
///   // Some("max-age=3600")
///   let missing = header.get_header(headers, "X-Missing")
///   // None
///
///   #(content_type, cache_control, missing)
/// }
/// ```
pub fn get_header(
  headers: List(Header),
  name: String,
) -> option.Option(String) {
  let normalized_name = string.lowercase(name)
  find_header(headers, normalized_name)
}

fn find_header(
  headers: List(Header),
  normalized_name: String,
) -> option.Option(String) {
  case headers {
    [] -> option.None
    [Header(header_name, value), ..rest] -> {
      let matches = string.lowercase(header_name) == normalized_name
      case matches {
        True -> option.Some(value)
        False -> find_header(rest, normalized_name)
      }
    }
  }
}

/// Set or replace a header
///
/// If a header with this name exists (case-insensitive), replaces its value.
/// If not, adds a new header. Only one header with the given name will exist
/// in the result.
///
/// Use this when you want to ensure exactly one value for a header (most cases).
/// For headers that can appear multiple times (like Set-Cookie), use `add_header` instead.
///
/// ## Example
///
/// ### Set a header <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_set_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
///
/// pub fn replace_and_add() {
///   let headers = [Header("Content-Type", "text/plain")]
///
///   // Replace existing header
///   let updated = header.set_header(headers, "content-type", "application/json")
///   // Result: [Header("content-type", "application/json")]
///
///   // Add new header
///   header.set_header(updated, "Cache-Control", "max-age=3600")
///   // Result: [
///   //   Header("Cache-Control", "max-age=3600"),
///   //   Header("content-type", "application/json")
///   // ]
/// }
/// ```
pub fn set_header(
  headers: List(Header),
  name: String,
  value: String,
) -> List(Header) {
  let normalized_name = string.lowercase(name)
  let filtered = filter_matching_headers(headers, normalized_name)
  [Header(name, value), ..filtered]
}

fn filter_matching_headers(
  headers: List(Header),
  normalized_name: String,
) -> List(Header) {
  filter_headers_recursive(headers, normalized_name, [])
}

fn filter_headers_recursive(
  headers: List(Header),
  normalized_name: String,
  kept_headers: List(Header),
) -> List(Header) {
  case headers {
    [] -> list.reverse(kept_headers)
    [header, ..rest] -> {
      let header_normalized = string.lowercase(header_name(header))
      let should_keep = header_normalized != normalized_name
      case should_keep {
        True ->
          filter_headers_recursive(rest, normalized_name, [
            header,
            ..kept_headers
          ])
        False -> filter_headers_recursive(rest, normalized_name, kept_headers)
      }
    }
  }
}

/// Add a header without removing existing ones with the same name
///
/// Adds a new header even if one with the same name already exists.
/// This allows multiple headers with the same name, which is valid for
/// some headers like Set-Cookie, Warning, or Accept.
///
/// Use this when you need multiple values for the same header name.
/// For most headers, use `set_header` instead to ensure only one value.
///
/// ## Example
///
/// ### Add a header <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_add_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header
///
/// pub fn add_cookies() {
///   let headers = []
///
///   // Add multiple Set-Cookie headers
///   headers
///   |> header.add_header("Set-Cookie", "session=abc; HttpOnly")
///   |> header.add_header("Set-Cookie", "preferences=dark; Path=/")
///   // Result: [
///   //   Header("Set-Cookie", "preferences=dark; Path=/"),
///   //   Header("Set-Cookie", "session=abc; HttpOnly")
///   // ]
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
/// Removes all headers with the given name (case-insensitive).
/// Returns a new list with matching headers filtered out.
///
/// ## Example
///
/// ### Remove a header <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_http_remove_header.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/header.{Header}
///
/// pub fn remove_debug() {
///   let headers = [
///     Header("Content-Type", "application/json"),
///     Header("Cache-Control", "max-age=3600"),
///     Header("X-Debug", "true"),
///   ]
///
///   header.remove_header(headers, "x-debug")
///   // Result: [
///   //   Header("Content-Type", "application/json"),
///   //   Header("Cache-Control", "max-age=3600")
///   // ]
/// }
/// ```
pub fn remove_header(headers: List(Header), name: String) -> List(Header) {
  let normalized_name = string.lowercase(name)
  filter_matching_headers(headers, normalized_name)
}
