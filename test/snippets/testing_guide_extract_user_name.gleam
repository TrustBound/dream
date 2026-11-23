import dream/http/validation.{type ValidationError}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}
import snippets/testing_guide_user.{type User}

/// Extract user name from validation result
pub fn extract_user_name(
  result: MatchResult(Result(User, List(ValidationError))),
  getter: fn(User) -> String,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(Ok(user)) -> MatchOk(getter(user))
    MatchOk(Error(_)) -> validation_failed_failure()
  }
}

fn validation_failed_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_user_name",
    message: "Expected Ok but got validation error",
    payload: Some(CustomMatcherFailure(
      actual: "Error(...)",
      description: "Validation failed",
    )),
  ))
}
