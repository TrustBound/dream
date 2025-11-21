//// Pattern matching utilities for router path patterns
////
//// Supports various pattern types:
//// - Static segments: "users"
//// - Named parameters: ":id"
//// - Single wildcards: "*" or "*name"
//// - Multi-segment wildcards: "**" or "**path"
//// - Extension patterns: "*.jpg" or "*.{jpg,png,gif}"
////
//// This is an internal module used by the router for path matching.
//// Most applications won't need to use this directly - the router
//// handles pattern matching automatically.
////
//// ## Pattern Examples
////
//// ```gleam
//// // Static: /users/profile
//// // Param: /users/:id → extracts id
//// // Single wildcard: /files/* → matches one segment
//// // Multi wildcard: /files/** → matches multiple segments
//// // Extension: /images/*.jpg → matches .jpg files
//// // Multiple extensions: /images/*.{jpg,png,gif}
//// ```

import gleam/list
import gleam/option
import gleam/string

/// Pattern segment type
///
/// Classifies what kind of pattern segment we're matching against.
/// Used internally by the pattern matcher to determine how to handle
/// each segment of a route pattern.
///
/// ## Variants
///
/// - `StaticSegment`: Exact match required (e.g., "users")
/// - `ParamSegment`: Named parameter (e.g., ":id")
/// - `SingleWildcard`: Matches one segment (e.g., "*" or "*name")
/// - `MultiWildcard`: Matches multiple segments (e.g., "**" or "**path")
/// - `ExtensionPattern`: Matches file extension (e.g., "*.jpg")
pub type PatternType {
  StaticSegment
  ParamSegment
  SingleWildcard
  MultiWildcard
  ExtensionPattern
}

/// Match a pattern against path segments and extract parameters
///
/// Core pattern matching function that compares a route pattern
/// (split into segments) against a request path (also split into segments).
/// Returns extracted parameters if the pattern matches, None if it doesn't.
///
/// ## Parameters
///
/// - `pattern_segments`: Route pattern split by "/" (e.g., ["users", ":id"])
/// - `path_segments`: Request path split by "/" (e.g., ["users", "123"])
///
/// ## Returns
///
/// - `Some(params)`: List of extracted parameters as key-value tuples
/// - `None`: Pattern doesn't match the path
///
/// ## Examples
///
/// ```gleam
/// // Named parameter
/// match_segments(["users", ":id"], ["users", "123"])
/// // Some([#("id", "123")])
///
/// // Multiple parameters
/// match_segments(["users", ":user_id", "posts", ":id"], ["users", "1", "posts", "2"])
/// // Some([#("user_id", "1"), #("id", "2")])
///
/// // Wildcard
/// match_segments(["files", "**path"], ["files", "docs", "guide.pdf"])
/// // Some([#("path", "docs/guide.pdf")])
///
/// // No match
/// match_segments(["users", ":id"], ["posts", "123"])
/// // None
/// ```
pub fn match_segments(
  pattern_segments: List(String),
  path_segments: List(String),
) -> option.Option(List(#(String, String))) {
  extract_params(pattern_segments, path_segments, [])
}

/// Classify what type of pattern a segment is
fn classify_pattern(segment: String) -> PatternType {
  let starts_with_colon = string.starts_with(segment, ":")
  let starts_with_star = string.starts_with(segment, "*")
  let starts_with_double_star = string.starts_with(segment, "**")
  let starts_with_star_dot = string.starts_with(segment, "*.")

  case
    starts_with_colon,
    starts_with_double_star,
    starts_with_star_dot,
    starts_with_star
  {
    True, _, _, _ -> ParamSegment
    _, True, _, _ -> MultiWildcard
    _, _, True, _ -> ExtensionPattern
    _, _, _, True -> SingleWildcard
    _, _, _, _ -> StaticSegment
  }
}

/// Extract name from pattern segment (for params and named wildcards)
/// ":id" → Some("id"), "*name" → Some("name"), "**path" → Some("path")
/// "*" → None, "**" → None, "static" → None
fn extract_pattern_name(
  segment: String,
  pattern_type: PatternType,
) -> option.Option(String) {
  case pattern_type {
    ParamSegment -> option.Some(string.drop_start(segment, 1))
    SingleWildcard if segment == "*" -> option.None
    SingleWildcard -> option.Some(string.drop_start(segment, 1))
    MultiWildcard if segment == "**" -> option.None
    MultiWildcard -> option.Some(string.drop_start(segment, 2))
    ExtensionPattern -> {
      // For *.jpg, extract nothing (anonymous)
      option.None
    }
    _ -> option.None
  }
}

/// Add parameter to list if name is provided
fn maybe_add_param(
  name: option.Option(String),
  value: String,
  params: List(#(String, String)),
) -> List(#(String, String)) {
  case name {
    option.Some(n) -> [#(n, value), ..params]
    option.None -> params
  }
}

/// Parse extension pattern and check if filename matches
/// Supports: *.jpg and *.{jpg,png,gif}
fn matches_extension(filename: String, pattern: String) -> Bool {
  let ext_pattern = string.drop_start(pattern, 2)
  let has_braces =
    string.starts_with(ext_pattern, "{") && string.ends_with(ext_pattern, "}")

  case has_braces {
    False -> string.ends_with(filename, "." <> ext_pattern)
    True -> matches_brace_extensions(filename, ext_pattern)
  }
}

fn matches_brace_extensions(filename: String, brace_pattern: String) -> Bool {
  let inner = brace_pattern |> string.drop_start(1) |> string.drop_end(1)
  let extensions = string.split(inner, ",")

  list.any(extensions, fn(ext) {
    string.ends_with(filename, "." <> string.trim(ext))
  })
}

/// Extract path parameters from pattern segments and path segments
fn extract_params(
  pattern_segments: List(String),
  path_segments: List(String),
  accumulated_params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case pattern_segments, path_segments {
    [], [] -> option.Some(list.reverse(accumulated_params))
    [], _ -> option.None
    [pattern_seg, ..rest_pat], _ -> {
      let pattern_type = classify_pattern(pattern_seg)
      extract_params_by_type(
        pattern_type,
        pattern_seg,
        rest_pat,
        path_segments,
        accumulated_params,
      )
    }
  }
}

/// Route to appropriate handler based on pattern type
fn extract_params_by_type(
  pattern_type: PatternType,
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case pattern_type {
    MultiWildcard ->
      handle_multi_wildcard(pattern_seg, rest_pattern, path_segments, params)

    SingleWildcard ->
      handle_single_wildcard(pattern_seg, rest_pattern, path_segments, params)

    ExtensionPattern ->
      handle_extension_pattern(pattern_seg, rest_pattern, path_segments, params)

    ParamSegment ->
      handle_param_segment(pattern_seg, rest_pattern, path_segments, params)

    StaticSegment ->
      handle_static_segment(pattern_seg, rest_pattern, path_segments, params)
  }
}

/// Handle :param segment
fn handle_param_segment(
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case path_segments {
    [] -> option.None
    [path_seg, ..rest_path] -> {
      let param_name = string.drop_start(pattern_seg, 1)
      let updated_params = [#(param_name, path_seg), ..params]
      extract_params(rest_pattern, rest_path, updated_params)
    }
  }
}

/// Handle static segment
fn handle_static_segment(
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case path_segments {
    [] -> option.None
    [path_seg, ..rest_path] -> {
      // Strip format extension from path segment before comparing
      let path_without_format = strip_format_extension(path_seg)
      case path_without_format == pattern_seg {
        True -> extract_params(rest_pattern, rest_path, params)
        False -> option.None
      }
    }
  }
}

/// Strip format extension from a path segment
/// "products.json" -> "products", "users.csv" -> "users", "file" -> "file"
fn strip_format_extension(segment: String) -> String {
  case string.split(segment, ".") {
    [base, _ext] -> base
    _ -> segment
  }
}

/// Handle * or *name segment
fn handle_single_wildcard(
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case path_segments {
    [] -> option.None
    [path_seg, ..rest_path] -> {
      let name = extract_pattern_name(pattern_seg, SingleWildcard)
      let updated_params = maybe_add_param(name, path_seg, params)
      extract_params(rest_pattern, rest_path, updated_params)
    }
  }
}

/// Handle *.ext or *.{ext1,ext2} segment
fn handle_extension_pattern(
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case path_segments {
    [] -> option.None
    [path_seg, ..rest_path] ->
      check_extension_and_continue(
        path_seg,
        pattern_seg,
        rest_pattern,
        rest_path,
        params,
      )
  }
}

fn check_extension_and_continue(
  path_seg: String,
  pattern_seg: String,
  rest_pattern: List(String),
  rest_path: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  let matches = matches_extension(path_seg, pattern_seg)

  case matches {
    False -> option.None
    True -> {
      let name = extract_pattern_name(pattern_seg, ExtensionPattern)
      let updated_params = maybe_add_param(name, path_seg, params)
      extract_params(rest_pattern, rest_path, updated_params)
    }
  }
}

/// Handle ** or **name segment
fn handle_multi_wildcard(
  pattern_seg: String,
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  let name = extract_pattern_name(pattern_seg, MultiWildcard)

  case rest_pattern {
    [] -> handle_multi_wildcard_at_end(name, path_segments, params)
    _ ->
      handle_multi_wildcard_in_middle(name, rest_pattern, path_segments, params)
  }
}

/// ** at end of pattern - capture all remaining segments
fn handle_multi_wildcard_at_end(
  name: option.Option(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  let captured = string.join(path_segments, "/")
  let updated_params = maybe_add_param(name, captured, params)
  option.Some(list.reverse(updated_params))
}

/// ** in middle - try matching rest of pattern at each position
fn handle_multi_wildcard_in_middle(
  name: option.Option(String),
  rest_pattern: List(String),
  path_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  try_match_at_positions(name, rest_pattern, path_segments, [], params)
}

/// Try matching rest of pattern starting at different positions
fn try_match_at_positions(
  wildcard_name: option.Option(String),
  rest_pattern: List(String),
  remaining_path: List(String),
  consumed_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  // Try matching from current position
  let captured = string.join(list.reverse(consumed_segments), "/")
  let updated_params = maybe_add_param(wildcard_name, captured, params)
  let match_result =
    extract_params(rest_pattern, remaining_path, updated_params)

  case match_result {
    option.Some(_) -> match_result
    option.None ->
      try_next_position(
        wildcard_name,
        rest_pattern,
        remaining_path,
        consumed_segments,
        params,
      )
  }
}

/// Continue trying at next position
fn try_next_position(
  wildcard_name: option.Option(String),
  rest_pattern: List(String),
  remaining_path: List(String),
  consumed_segments: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case remaining_path {
    [] -> option.None
    [seg, ..rest] -> {
      try_match_at_positions(
        wildcard_name,
        rest_pattern,
        rest,
        [seg, ..consumed_segments],
        params,
      )
    }
  }
}
