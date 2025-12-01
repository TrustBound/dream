//// Custom matcher to extract a field from a form.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/list
import gleam/option.{Some}

/// Extract a field value from a form (List of key-value tuples) for further assertions.
///
/// ## Example
///
/// ```gleam
/// require_form(request)
/// |> should()
/// |> be_ok()
/// |> extract_field("title")
/// |> equal("Hello")
/// |> or_fail_with("title should be 'Hello'")
/// ```
///
pub fn extract_field(
  key: String,
) -> fn(MatchResult(List(#(String, String)))) -> MatchResult(String) {
  fn(result: MatchResult(List(#(String, String)))) {
    case result {
      MatchFailed(failure) -> MatchFailed(failure)
      MatchOk(form) -> {
        case list.key_find(form, key) {
          Ok(value) -> MatchOk(value)
          Error(_) ->
            MatchFailed(AssertionFailure(
              operator: "extract_field",
              message: "Expected to find field '" <> key <> "'",
              payload: Some(CustomMatcherFailure(
                actual: format_form(form),
                description: "Field not found",
              )),
            ))
        }
      }
    }
  }
}

fn format_form(form: List(#(String, String))) -> String {
  form
  |> list.map(fn(pair) {
    let #(key, value) = pair
    key <> "=" <> value
  })
  |> list.intersperse(", ")
  |> list.fold("", fn(accumulator, item) { accumulator <> item })
}
