//// Custom matcher to count headers with a given name in a mist response.

import dream_test/types.{type MatchResult, MatchFailed, MatchOk}
import gleam/http/response.{type Response}
import gleam/list
import mist.{type ResponseData}

/// Count headers with the given name, returning the count for further assertions.
///
/// ## Example
///
/// ```gleam
/// mist_response.convert(dream_response)
/// |> should()
/// |> count_mist_headers("set-cookie")
/// |> equal(2)
/// |> or_fail_with("Should have 2 Set-Cookie headers")
/// ```
///
pub fn count_mist_headers(
  result: MatchResult(Response(ResponseData)),
  name: String,
) -> MatchResult(Int) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> {
      let count =
        response.headers
        |> list.filter(fn(header) { header.0 == name })
        |> list.length()
      MatchOk(count)
    }
  }
}
