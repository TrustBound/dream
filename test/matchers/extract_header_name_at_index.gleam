//// Custom matcher to extract a header name at a specific index.

import dream/http/header.{type Header, Header}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/int
import gleam/list
import gleam/option.{Some}

/// Extract the header name at a specific index for further assertions.
///
/// ## Example
///
/// ```gleam
/// response.headers
/// |> should()
/// |> extract_header_name_at_index(0)
/// |> equal("X-Custom")
/// |> or_fail_with("First header should be X-Custom")
/// ```
///
pub fn extract_header_name_at_index(
  result: MatchResult(List(Header)),
  index: Int,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(headers) -> get_header_at_index(headers, index)
  }
}

fn get_header_at_index(headers: List(Header), index: Int) -> MatchResult(String) {
  case get_at(headers, index) {
    Ok(Header(name, _value)) -> MatchOk(name)
    Error(Nil) -> index_out_of_bounds_failure(index, list.length(headers))
  }
}

fn get_at(items: List(a), index: Int) -> Result(a, Nil) {
  items
  |> list.drop(index)
  |> list.first
}

fn index_out_of_bounds_failure(index: Int, length: Int) -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_header_name_at_index",
    message: "Expected header at index " <> int.to_string(index),
    payload: Some(CustomMatcherFailure(
      actual: "Headers list has " <> int.to_string(length) <> " items",
      description: "Index out of bounds",
    )),
  ))
}
