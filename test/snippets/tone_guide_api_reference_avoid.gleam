//// An API reference doc comment in the wrong tone. The code is the same as
//// tone_guide_api_reference; only the comment is bad. Shown in
//// docs/contributing/tone-guide.md.

import gleam/option.{type Option}
import snippets/tone_guide_api_reference

/// This is how Dream's router works its magic! Well, not magic
/// really - just good old-fashioned pattern matching. You give
/// it a pattern like "/users/:id" and it'll extract that :id
/// for you. Pretty neat, huh?
pub fn match_path(
  pattern: String,
  path: String,
) -> Option(List(#(String, String))) {
  tone_guide_api_reference.match_path(pattern, path)
}
