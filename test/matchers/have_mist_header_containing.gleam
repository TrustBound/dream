//// Custom matcher to check if a mist response has a header containing substring.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import mist.{type ResponseData}

/// Check if a mist response has a header containing a substring in its value.
///
/// ## Example
///
/// ```gleam
/// mist_response.convert(dream_response)
/// |> should()
/// |> have_mist_header_containing("set-cookie", "session=")
/// |> or_fail_with("Should have session cookie")
/// ```
///
pub fn have_mist_header_containing(
  result: MatchResult(Response(ResponseData)),
  name: String,
  substring: String,
) -> MatchResult(Response(ResponseData)) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> check_header_contains(response, name, substring)
  }
}

fn check_header_contains(
  response: Response(ResponseData),
  name: String,
  substring: String,
) -> MatchResult(Response(ResponseData)) {
  let has_header =
    list.any(response.headers, fn(header) {
      let #(header_name, header_value) = header
      header_name == name && string.contains(header_value, substring)
    })

  case has_header {
    True -> MatchOk(response)
    False -> header_not_found_failure(name, substring, response.headers)
  }
}

fn header_not_found_failure(
  name: String,
  substring: String,
  headers: List(#(String, String)),
) -> MatchResult(Response(ResponseData)) {
  MatchFailed(AssertionFailure(
    operator: "have_mist_header_containing",
    message: "Expected header '" <> name <> "' containing '" <> substring <> "'",
    payload: Some(CustomMatcherFailure(
      actual: format_headers(headers),
      description: "Response headers",
    )),
  ))
}

fn format_headers(headers: List(#(String, String))) -> String {
  headers
  |> list.map(fn(header) {
    let #(header_name, header_value) = header
    header_name <> ": " <> header_value
  })
  |> string.join(", ")
}
