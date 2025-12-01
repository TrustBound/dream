//// Custom matcher to extract a field from a list of form fields.

import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/list
import gleam/option.{Some}

/// Extract the value of a specific field from a form field list.
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
  result: MatchResult(List(#(String, String))),
  name: String,
) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(fields) -> find_field(fields, name)
  }
}

fn find_field(
  fields: List(#(String, String)),
  name: String,
) -> MatchResult(String) {
  case list.find(fields, fn(field) { field.0 == name }) {
    Ok(#(_field_name, value)) -> MatchOk(value)
    Error(Nil) -> field_not_found_failure(name, fields)
  }
}

fn field_not_found_failure(
  name: String,
  fields: List(#(String, String)),
) -> MatchResult(String) {
  let available =
    fields
    |> list.map(fn(field) { field.0 })
    |> list.fold("", fn(acc, field_name) {
      case acc {
        "" -> field_name
        _ -> acc <> ", " <> field_name
      }
    })

  MatchFailed(AssertionFailure(
    operator: "extract_field",
    message: "Field '" <> name <> "' not found",
    payload: Some(CustomMatcherFailure(
      actual: "Available fields: " <> available,
      description: "Field not found in form data",
    )),
  ))
}
