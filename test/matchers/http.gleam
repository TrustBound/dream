//// Custom HTTP matchers for dream_test.
////
//// Provides response-specific matchers that integrate with dream_test's
//// assertion chaining pattern.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option
import gleam/string

/// Check if response has a header whose value contains a substring.
/// Passes the response through for further chaining.
///
/// ## Example
///
/// ```gleam
/// response
/// |> should()
/// |> have_header_containing("set-cookie", "session=")
/// |> or_fail_with("Expected session cookie")
/// ```
pub fn have_header_containing(
  name: String,
  substring: String,
) -> fn(MatchResult(Response(a))) -> MatchResult(Response(a)) {
  fn(result) {
    case result {
      MatchFailed(failure) -> MatchFailed(failure)
      MatchOk(resp) -> check_header_containing(resp, name, substring)
    }
  }
}

fn check_header_containing(
  resp: Response(a),
  name: String,
  substring: String,
) -> MatchResult(Response(a)) {
  let lower_name = string.lowercase(name)
  case list.find(resp.headers, fn(h) { string.lowercase(h.0) == lower_name }) {
    Ok(#(_, value)) ->
      case string.contains(value, substring) {
        True -> MatchOk(resp)
        False ->
          MatchFailed(AssertionFailure(
            operator: "have_header_containing",
            message: "",
            payload: option.Some(CustomMatcherFailure(
              actual: "'" <> value <> "'",
              description: "contain '" <> substring <> "'",
            )),
          ))
      }
    Error(_) ->
      MatchFailed(AssertionFailure(
        operator: "have_header_containing",
        message: "",
        payload: option.Some(CustomMatcherFailure(
          actual: "(header not found)",
          description: "have header '" <> name <> "'",
        )),
      ))
  }
}

/// Extract a header value for chaining with other matchers.
/// Unwraps the header value so you can chain with equal(), contain_string(), etc.
///
/// ## Example
///
/// ```gleam
/// response
/// |> should()
/// |> have_header("content-type")
/// |> contain_string("json")
/// |> or_fail_with("Expected JSON content type")
/// ```
pub fn have_header(
  name: String,
) -> fn(MatchResult(Response(a))) -> MatchResult(String) {
  fn(result) {
    case result {
      MatchFailed(failure) -> MatchFailed(failure)
      MatchOk(resp) -> extract_header_value(resp, name)
    }
  }
}

fn extract_header_value(resp: Response(a), name: String) -> MatchResult(String) {
  let lower_name = string.lowercase(name)
  case list.find(resp.headers, fn(h) { string.lowercase(h.0) == lower_name }) {
    Ok(#(_, value)) -> MatchOk(value)
    Error(_) ->
      MatchFailed(AssertionFailure(
        operator: "have_header",
        message: "",
        payload: option.Some(CustomMatcherFailure(
          actual: "(missing)",
          description: "have header '" <> name <> "'",
        )),
      ))
  }
}

/// Check that response has exactly N headers with the given name.
/// Passes the response through for further chaining.
///
/// ## Example
///
/// ```gleam
/// response
/// |> should()
/// |> have_header_count("set-cookie", 2)
/// |> or_fail_with("Expected 2 cookies")
/// ```
pub fn have_header_count(
  name: String,
  expected: Int,
) -> fn(MatchResult(Response(a))) -> MatchResult(Response(a)) {
  fn(result) {
    case result {
      MatchFailed(failure) -> MatchFailed(failure)
      MatchOk(resp) -> check_header_count(resp, name, expected)
    }
  }
}

fn check_header_count(
  resp: Response(a),
  name: String,
  expected: Int,
) -> MatchResult(Response(a)) {
  let lower_name = string.lowercase(name)
  let count =
    list.count(resp.headers, fn(h) { string.lowercase(h.0) == lower_name })
  case count == expected {
    True -> MatchOk(resp)
    False ->
      MatchFailed(AssertionFailure(
        operator: "have_header_count",
        message: "",
        payload: option.Some(CustomMatcherFailure(
          actual: int.to_string(count) <> " headers",
          description: int.to_string(expected)
            <> " headers named '"
            <> name
            <> "'",
        )),
      ))
  }
}
