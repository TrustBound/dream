//// Custom matcher to check if a mist response has a header with exact value.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import mist.{type ResponseData}

/// Check if a mist response has a header with the given name and exact value.
///
/// ## Example
///
/// ```gleam
/// mist_response.convert(dream_response)
/// |> should()
/// |> have_mist_header("content-type", "application/json")
/// |> or_fail_with("Should have JSON content type")
/// ```
///
pub fn have_mist_header(
  result: MatchResult(Response(ResponseData)),
  name: String,
  value: String,
) -> MatchResult(Response(ResponseData)) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> check_header(response, name, value)
  }
}

fn check_header(
  response: Response(ResponseData),
  name: String,
  value: String,
) -> MatchResult(Response(ResponseData)) {
  let has_header =
    list.any(response.headers, fn(header) {
      let #(header_name, header_value) = header
      header_name == name && header_value == value
    })

  case has_header {
    True -> MatchOk(response)
    False -> header_not_found_failure(name, value, response.headers)
  }
}

fn header_not_found_failure(
  name: String,
  value: String,
  headers: List(#(String, String)),
) -> MatchResult(Response(ResponseData)) {
  MatchFailed(AssertionFailure(
    operator: "have_mist_header",
    message: "Expected header '" <> name <> "' with value '" <> value <> "'",
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
