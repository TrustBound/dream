// Pattern Parser - Convert string paths to structured segments
//
// Parses patterns like "/users/:id/posts/**path" into segment lists
// for use with the radix trie router.

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import radix_poc.{type Segment}

/// Parse a path pattern string into a list of segments
///
/// ## Examples
///
/// ```gleam
/// parse_pattern("/users")
/// // [Literal("users")]
///
/// parse_pattern("/users/:id")
/// // [Literal("users"), Param("id")]
///
/// parse_pattern("/public/**filepath")
/// // [Literal("public"), MultiWildcard(Some("filepath"))]
///
/// parse_pattern("/images/*.{jpg,png}")
/// // [Literal("images"), ExtensionPattern(["jpg", "png"])]
/// ```
pub fn parse_pattern(pattern: String) -> List(Segment) {
  pattern
  |> string.split("/")
  |> list.filter(fn(seg) { seg != "" })
  |> list.map(parse_segment)
}

/// Parse a single segment string into a Segment type
fn parse_segment(segment: String) -> Segment {
  case segment {
    // Named parameter: :id
    ":" <> name -> radix_poc.Param(name)

    // Multi-wildcard: ** or **name
    "**" -> radix_poc.MultiWildcard(None)
    "**" <> name -> radix_poc.MultiWildcard(Some(name))

    // Extension pattern: *.ext or *.{ext1,ext2}
    "*." <> ext_pattern -> parse_extension_pattern(ext_pattern)

    // Single wildcard: * or *name
    "*" -> radix_poc.SingleWildcard(None)
    "*" <> name -> radix_poc.SingleWildcard(Some(name))

    // Literal segment
    _ -> radix_poc.Literal(segment)
  }
}

/// Parse extension pattern from the part after "*."
fn parse_extension_pattern(ext_pattern: String) -> Segment {
  case string.starts_with(ext_pattern, "{") {
    True -> parse_brace_extensions(ext_pattern)
    False -> radix_poc.ExtensionPattern([ext_pattern])
  }
}

/// Parse brace-delimited extensions: {jpg,png,gif}
fn parse_brace_extensions(brace_pattern: String) -> Segment {
  let inner =
    brace_pattern
    |> string.drop_start(1)
    // Remove leading {
    |> string.drop_end(1)
  // Remove trailing }

  let extensions =
    inner
    |> string.split(",")
    |> list.map(string.trim)

  radix_poc.ExtensionPattern(extensions)
}
