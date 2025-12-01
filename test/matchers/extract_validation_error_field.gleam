//// Custom matcher to extract the field name from a validation error.

import dream/http/validation
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{None, Some}

/// Extract the field name from a validation error.
///
/// ## Example
///
/// ```gleam
/// validation.validate_json(body, user_decoder())
/// |> should()
/// |> extract_validation_error_field()
/// |> equal("email")
/// |> or_fail_with("Field should be 'email'")
/// ```
///
pub fn extract_validation_error_field(
  result: MatchResult(Result(a, validation.ValidationError)),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Error(validation.ValidationError(
      _message,
      Some(field_name),
      _path,
      _value,
    ))) -> MatchOk(field_name)
    MatchOk(Error(validation.ValidationError(_message, None, _path, _value))) ->
      no_field_name_failure()
    MatchOk(Ok(_success)) -> unexpected_success_failure()
  }
}

fn no_field_name_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_validation_error_field",
    message: "Validation error has no field name",
    payload: None,
  ))
}

fn unexpected_success_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_validation_error_field",
    message: "Expected Error result but got Ok",
    payload: Some(CustomMatcherFailure(
      actual: "Ok(...)",
      description: "Validation succeeded unexpectedly",
    )),
  ))
}
