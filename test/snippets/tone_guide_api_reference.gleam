//// An API reference doc comment in the right tone. Shown in
//// docs/contributing/tone-guide.md.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Match a path against a pattern and extract parameters.
///
/// Returns the extracted parameters if the path matches the pattern,
/// or `None` if it doesn't.
///
/// ## Examples
///
/// ### Match a user path <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/tone_guide_api_reference_example.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import gleam/option.{type Option}
/// import snippets/tone_guide_api_reference.{match_path}
///
/// pub fn match_user_path() -> Option(List(#(String, String))) {
///   match_path("/users/:id", "/users/123")
///   // -> Some([#("id", "123")])
/// }
/// ```
pub fn match_path(
  pattern: String,
  path: String,
) -> Option(List(#(String, String))) {
  let pattern_segments = string.split(pattern, "/")
  let path_segments = string.split(path, "/")
  case list.strict_zip(pattern_segments, path_segments) {
    Ok(segment_pairs) -> collect_params(segment_pairs, [])
    Error(Nil) -> None
  }
}

fn collect_params(
  segment_pairs: List(#(String, String)),
  params: List(#(String, String)),
) -> Option(List(#(String, String))) {
  case segment_pairs {
    [] -> Some(list.reverse(params))
    [#(":" <> name, value), ..rest] ->
      collect_params(rest, [#(name, value), ..params])
    [#(pattern_segment, path_segment), ..rest]
      if pattern_segment == path_segment
    -> collect_params(rest, params)
    [_mismatch, ..] -> None
  }
}
