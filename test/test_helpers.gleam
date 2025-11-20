//// Shared test helpers for Dream test suite
////
//// Provides reusable utilities for testing HTTP responses,
//// headers, cookies, and other common test scenarios.
////
//// Usage:
//// ```gleam
//// import test_helpers.{has_header, has_header_containing, get_header_value}
////
//// has_header(response, "content-type", "application/json")
////   |> should.be_true()
//// ```

import gleam/http/response.{type Response}
import gleam/list
import gleam/result
import gleam/string
import mist.{type ResponseData}

// Header comparison functions

fn header_matches(
  header: #(String, String),
  name: String,
  value: String,
) -> Bool {
  let #(header_name, header_value) = header
  header_name == name && header_value == value
}

fn header_name_matches(header: #(String, String), name: String) -> Bool {
  let #(header_name, _) = header
  header_name == name
}

fn header_contains(
  header: #(String, String),
  name: String,
  substring: String,
) -> Bool {
  let #(header_name, header_value) = header
  header_name == name && string.contains(header_value, substring)
}

fn extract_header_value(header: #(String, String)) -> String {
  let #(_, value) = header
  value
}

// Public header assertion helpers

/// Check if response has a header with exact name and value
pub fn has_header(
  response: Response(ResponseData),
  name: String,
  value: String,
) -> Bool {
  list.any(response.headers, header_matches(_, name, value))
}

/// Check if response has a header containing a substring in its value
pub fn has_header_containing(
  response: Response(ResponseData),
  name: String,
  substring: String,
) -> Bool {
  list.any(response.headers, header_contains(_, name, substring))
}

/// Get the value of a header by name
pub fn get_header_value(
  response: Response(ResponseData),
  name: String,
) -> Result(String, Nil) {
  response.headers
  |> list.find(header_name_matches(_, name))
  |> result.map(extract_header_value)
}

/// Count how many headers match the given name
pub fn count_headers(response: Response(ResponseData), name: String) -> Int {
  response.headers
  |> list.filter(header_name_matches(_, name))
  |> list.length()
}
