//// Custom matcher to extract a header value from a mist response.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import mist.{type ResponseData}

/// Extract a header value from a mist response for further assertions.
///
/// ## Example
///
/// ```gleam
/// mist_response.convert(dream_response)
/// |> should()
/// |> extract_mist_header_value("set-cookie")
/// |> contain_string("Secure")
/// |> or_fail_with("Should have Secure attribute")
/// ```
///
pub fn extract_mist_header_value(
  result: MatchResult(Response(ResponseData)),
  name: String,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> find_header_value(response.headers, name)
  }
}

fn find_header_value(
  headers: List(#(String, String)),
  name: String,
) -> MatchResult(String) {
  let found =
    headers
    |> list.find(fn(header) {
      let #(header_name, _header_value) = header
      header_name == name
    })
    |> result.map(fn(header) {
      let #(_header_name, header_value) = header
      header_value
    })

  case found {
    Ok(value) -> MatchOk(value)
    Error(Nil) -> header_not_found_failure(name, headers)
  }
}

fn header_not_found_failure(
  name: String,
  headers: List(#(String, String)),
) -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_mist_header_value",
    message: "Expected header '" <> name <> "' not found",
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
