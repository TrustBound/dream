//// Custom matcher to extract the message from a validation error.

import dream/http/validation
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the message from a validation error.
///
/// ## Example
///
/// ```gleam
/// validation.validate_json(body, user_decoder())
/// |> should()
/// |> extract_validation_error_message()
/// |> contain_string("Invalid JSON")
/// |> or_fail_with("Should mention Invalid JSON")
/// ```
///
pub fn extract_validation_error_message(
  result: MatchResult(Result(a, validation.ValidationError)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Error(validation.ValidationError(message, _field, _path, _value))) ->
      MatchOk(message)
    MatchOk(Ok(_success)) -> unexpected_success_failure()
  }
}

fn unexpected_success_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_validation_error_message",
    message: "Expected Error result but got Ok",
    payload: Some(CustomMatcherFailure(
      actual: "Ok(...)",
      description: "Validation succeeded unexpectedly",
    )),
  ))
}
