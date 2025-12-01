//// Custom matcher to extract route params from a route result.

import dream/context
import dream/router
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Extract the params from a route match result for further assertions.
///
/// ## Example
///
/// ```gleam
/// find_route(test_router, request)
/// |> should()
/// |> be_some()
/// |> extract_route_params()
/// |> equal([#("id", "123")])
/// |> or_fail_with("params should contain id")
/// ```
///
pub fn extract_route_params(
  result: MatchResult(
    #(router.Route(context.AppContext, services), List(#(String, String))),
  ),
) -> MatchResult(List(#(String, String))) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(#(_route, params)) -> MatchOk(params)
  }
}
