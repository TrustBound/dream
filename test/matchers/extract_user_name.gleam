//// Custom matcher to extract a field from a validation result.

import dream/http/validation
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract a field from a successful validation result using a getter function.
///
/// ## Example
///
/// ```gleam
/// validation.validate_json(body, user_decoder())
/// |> should()
/// |> extract_user_name(fn(user: TestUser) { user.name })
/// |> equal("John")
/// |> or_fail_with("Name should be John")
/// ```
///
pub fn extract_user_name(
  result: MatchResult(Result(a, validation.ValidationError)),
  field_getter: fn(a) -> String,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Ok(user)) -> MatchOk(field_getter(user))
    MatchOk(Error(validation_error)) ->
      validation_failed_failure(validation_error)
  }
}

fn validation_failed_failure(
  error: validation.ValidationError,
) -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_user_field",
    message: "Expected Ok result but got validation error",
    payload: Some(CustomMatcherFailure(
      actual: error.message,
      description: "Validation failed",
    )),
  ))
}
