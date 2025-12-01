//// Custom matcher to extract an error message from a Result.

import dream/http/error.{BadRequest}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the error message from a Result(a, error.Error) for further assertions.
///
/// ## Example
///
/// ```gleam
/// require_int(request, "id")
/// |> should()
/// |> extract_error_message()
/// |> contain_string("Missing")
/// |> or_fail_with("Should mention 'Missing'")
/// ```
///
pub fn extract_error_message(
  result: MatchResult(Result(a, error.Error)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Ok(_value)) -> unexpected_ok_failure()
    MatchOk(Error(BadRequest(message))) -> MatchOk(message)
    MatchOk(Error(_other_error)) -> wrong_error_type_failure()
  }
}

fn unexpected_ok_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_error_message",
    message: "Expected an Error but got Ok",
    payload: Some(CustomMatcherFailure(
      actual: "Ok(...)",
      description: "Result was Ok, not Error",
    )),
  ))
}

fn wrong_error_type_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_error_message",
    message: "Expected BadRequest error",
    payload: Some(CustomMatcherFailure(
      actual: "Other error type",
      description: "Error was not BadRequest",
    )),
  ))
}
