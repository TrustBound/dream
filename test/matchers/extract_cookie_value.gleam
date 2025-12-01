//// Custom matcher to extract the first cookie value from a cookie list.

import dream/http/cookie.{type Cookie, cookie_value}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the first cookie's value from a list of cookies for further assertions.
///
/// ## Example
///
/// ```gleam
/// cookies
/// |> should()
/// |> extract_cookie_value()
/// |> equal("abc123")
/// |> or_fail_with("First cookie value should be 'abc123'")
/// ```
///
pub fn extract_cookie_value(
  result: MatchResult(List(Cookie)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk([first, ..]) -> MatchOk(cookie_value(first))
    MatchOk([]) -> empty_cookie_list_failure()
  }
}

fn empty_cookie_list_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_cookie_value",
    message: "Expected at least one cookie",
    payload: Some(CustomMatcherFailure(
      actual: "[]",
      description: "Cookie list is empty",
    )),
  ))
}
