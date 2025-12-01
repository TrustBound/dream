//// Custom matcher to extract body text from a Response.

import dream/http/response.{type Response, type ResponseBody, Text}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Extract the body text from a Response for further assertions.
///
/// ## Example
///
/// ```gleam
/// response
/// |> should()
/// |> extract_body_text()
/// |> equal("success")
/// |> or_fail_with("Body should be 'success'")
/// ```
///
pub fn extract_body_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> extract_from_body(response.body)
  }
}

fn extract_from_body(body: ResponseBody) -> MatchResult(String) {
  case body {
    Text(text) -> MatchOk(text)
    _non_text_body -> non_text_body_failure()
  }
}

fn non_text_body_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_body_text",
    message: "Expected Text body",
    payload: Some(CustomMatcherFailure(
      actual: "Non-text body type",
      description: "Body is not Text",
    )),
  ))
}
