//// Custom matcher to extract the streaming flag from a route result.

import dream/context
import dream/router
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Extract the streaming flag from a route match result for further assertions.
///
/// ## Example
///
/// ```gleam
/// find_route(test_router, request)
/// |> should()
/// |> be_some()
/// |> extract_streaming_flag()
/// |> be_true()
/// |> or_fail_with("streaming should be enabled")
/// ```
///
pub fn extract_streaming_flag(
  result: MatchResult(
    #(router.Route(context.AppContext, services), List(#(String, String))),
  ),
) -> MatchResult(Bool) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(#(matched_route, _params)) -> MatchOk(matched_route.streaming)
  }
}
