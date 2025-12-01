//// Custom matcher to extract the request ID from an AppContext.

import dream/context.{type AppContext, AppContext}
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Extract the request ID from an AppContext.
///
/// ## Example
///
/// ```gleam
/// context.new_context("test-123")
/// |> should()
/// |> extract_request_id()
/// |> equal("test-123")
/// |> or_fail_with("Request ID should be 'test-123'")
/// ```
///
pub fn extract_request_id(
  result: MatchResult(AppContext),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(AppContext(id)) -> MatchOk(id)
  }
}
