//// Custom matcher to extract the value of the first header.

import dream/http/header.{type Header, Header}
import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk,
}
import gleam/option.{None}

/// Extract the value of the first header in a list.
///
/// ## Example
///
/// ```gleam
/// response.headers
/// |> should()
/// |> extract_first_header_value()
/// |> equal("/users/123")
/// |> or_fail_with("First header value should be redirect location")
/// ```
///
pub fn extract_first_header_value(
  result: MatchResult(List(Header)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk([Header(_name, value), ..]) -> MatchOk(value)
    MatchOk([]) -> empty_headers_failure()
  }
}

fn empty_headers_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_first_header_value",
    message: "Expected at least one header but got empty list",
    payload: None,
  ))
}
