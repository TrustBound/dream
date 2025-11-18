//// HTTP header types and utilities
////
//// Types and functions for working with HTTP headers. Headers can be used
//// with both requests and responses.

import gleam/list
import gleam/option
import gleam/string

/// HTTP header type
pub type Header {
  Header(name: String, value: String)
}

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
  acc: List(Header),
) -> List(Header) {
  case headers {
    [] -> list.reverse(acc)
    [header, ..rest] -> {
      let header_normalized = string.lowercase(header_name(header))
      let should_keep = header_normalized != normalized_name
      case should_keep {
        True -> filter_headers_recursive(rest, normalized_name, [header, ..acc])
        False -> filter_headers_recursive(rest, normalized_name, acc)
      }
    }
  }
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
  filter_matching_headers(headers, normalized_name)
}
