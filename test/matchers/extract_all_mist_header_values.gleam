//// Custom matcher to extract all values for a header name from a mist response.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import mist.{type ResponseData}

/// Extract all values for a header name, returning a list for further assertions.
///
/// ## Example
///
/// ```gleam
/// mist_response.convert(dream_response)
/// |> should()
/// |> extract_all_mist_header_values("set-cookie")
/// |> have_length(2)
/// |> or_fail_with("Should have 2 Set-Cookie headers")
/// ```
///
pub fn extract_all_mist_header_values(
  result: MatchResult(Response(ResponseData)),
  name: String,
) -> MatchResult(List(String)) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> {
      let values =
        response.headers
        |> list.filter_map(fn(header) {
          case header.0 == name {
            True -> Ok(header.1)
            False -> Error(Nil)
          }
        })
      case values {
        [] -> header_not_found_failure(name, response.headers)
        _ -> MatchOk(values)
      }
    }
  }
}

fn header_not_found_failure(
  name: String,
  headers: List(#(String, String)),
) -> MatchResult(List(String)) {
  MatchFailed(AssertionFailure(
    operator: "extract_all_mist_header_values",
    message: "Expected header '" <> name <> "' not found",
    payload: Some(CustomMatcherFailure(
      actual: format_headers(headers),
      description: "Response headers",
    )),
  ))
}

fn format_headers(headers: List(#(String, String))) -> String {
  headers
  |> list.map(fn(header) { header.0 <> ": " <> header.1 })
  |> string.join(", ")
}
