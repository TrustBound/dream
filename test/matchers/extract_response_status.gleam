//// Custom matcher to extract status code from a Response.

import dream/http/response.{type Response}
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Extract the status code from a Response for further assertions.
///
/// ## Example
///
/// ```gleam
/// response
/// |> should()
/// |> extract_response_status()
/// |> equal(200)
/// |> or_fail_with("Status should be 200")
/// ```
///
pub fn extract_response_status(
  result: MatchResult(Response),
) -> MatchResult(Int) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> MatchOk(response.status)
  }
}
