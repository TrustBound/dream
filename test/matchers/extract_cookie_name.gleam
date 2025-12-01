//// Custom matcher to extract the first cookie name from a cookie list.

import dream/http/cookie.{type Cookie, cookie_name}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the first cookie's name from a list of cookies for further assertions.
///
/// ## Example
///
/// ```gleam
/// cookies
/// |> should()
/// |> extract_cookie_name()
/// |> equal("session")
/// |> or_fail_with("First cookie should be 'session'")
/// ```
///
pub fn extract_cookie_name(
  result: MatchResult(List(Cookie)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk([first, ..]) -> MatchOk(cookie_name(first))
    MatchOk([]) -> empty_cookie_list_failure()
  }
}

fn empty_cookie_list_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_cookie_name",
    message: "Expected at least one cookie",
    payload: Some(CustomMatcherFailure(
      actual: "[]",
      description: "Cookie list is empty",
    )),
  ))
}
