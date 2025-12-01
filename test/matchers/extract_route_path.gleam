//// Custom matcher to extract the path from a route result.

import dream/context
import dream/router
import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Extract the path from a route match result for further assertions.
///
/// ## Example
///
/// ```gleam
/// find_route(test_router, request)
/// |> should()
/// |> be_some()
/// |> extract_route_path()
/// |> equal("/users/:id")
/// |> or_fail_with("path should be /users/:id")
/// ```
///
pub fn extract_route_path(
  result: MatchResult(
    #(router.Route(context.AppContext, services), List(#(String, String))),
  ),
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(#(matched_route, _params)) -> MatchOk(matched_route.path)
  }
}
