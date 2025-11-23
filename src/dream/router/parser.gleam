//// Pattern Parser - Convert string paths to structured segments
////
//// Parses route pattern strings (like "/users/:id/posts/**path") into
//// structured segment lists that the radix trie can use for matching.
////
//// ## Pattern Syntax
////
//// - **Literal**: `users` - Matches exactly "users"
//// - **Parameter**: `:id` - Captures one segment as "id"
//// - **Single wildcard**: `*` or `*name` - Matches one segment
//// - **Multi wildcard**: `**` or `**path` - Matches zero or more segments
//// - **Extension**: `*.jpg` - Matches filenames ending in .jpg
//// - **Multiple extensions**: `*.{jpg,png,gif}` - Matches any of the listed extensions
////
//// ## Examples
////
//// ```gleam
//// parse_pattern("/users/:id")
//// // [Literal("users"), Param("id")]
////
//// parse_pattern("/files/**path")
//// // [Literal("files"), MultiWildcard(Some("path"))]
////
//// parse_pattern("/images/*.{jpg,png}")
//// // [Literal("images"), ExtensionPattern(["jpg", "png"])]
//// ```
////
//// ## Pattern Precedence
////
//// When multiple routes could match the same path, the most specific wins:
//// 1. Literal segments (highest priority)
//// 2. Parameters
//// 3. Single wildcards
//// 4. Extension patterns
//// 5. Multi-segment wildcards (lowest priority)

import dream/router/trie.{
  type Segment, ExtensionPattern, Literal, MultiWildcard, Param, SingleWildcard,
}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

// ============================================================================
// Public API
// ============================================================================

/// Parse a path pattern string into a list of segments
///
/// Converts a string path pattern into structured segments that can be
/// inserted into the radix trie. Handles all pattern types including
/// literals, parameters, wildcards, and extension patterns.
///
/// ## Parameters
///
/// - `pattern`: Path pattern string (e.g., "/users/:id")
///
/// ## Returns
///
/// List of segments representing the pattern structure
///
/// ## Examples
///
/// ```gleam
/// // Simple literal path
/// parse_pattern("/users")
/// // [Literal("users")]
///
/// // Parameter capture
/// parse_pattern("/users/:id")
/// // [Literal("users"), Param("id")]
///
/// // Multi-segment wildcard
/// parse_pattern("/public/**filepath")
/// // [Literal("public"), MultiWildcard(Some("filepath"))]
///
/// // Extension matching
/// parse_pattern("/images/*.{jpg,png}")
/// // [Literal("images"), ExtensionPattern(["jpg", "png"])]
/// ```
///
/// ## Pattern Details
///
/// - Leading and trailing slashes are ignored
/// - Empty segments (from multiple slashes) are filtered out
/// - Parameter names start with `:` (e.g., `:id`)
/// - Wildcards start with `*` for single-segment or `**` for multi-segment
/// - Extensions use `*.ext` or `*.{ext1,ext2,ext3}` syntax
pub fn parse_pattern(pattern: String) -> List(Segment) {
  pattern
  |> string.split("/")
  |> list.filter(is_non_empty_segment)
  |> list.map(parse_segment)
}

// ============================================================================
// Internal Helpers
// ============================================================================

/// Check if a segment is non-empty
///
/// Used to filter out empty segments from multiple slashes or leading/trailing slashes.
fn is_non_empty_segment(seg: String) -> Bool {
  seg != ""
}

/// Parse a single segment string into a Segment type
///
/// Determines the segment type based on its prefix and structure.
/// Handles all pattern syntaxes: parameters, wildcards, extensions, and literals.
fn parse_segment(segment: String) -> Segment {
  case segment {
    // Named parameter: :id
    ":" <> name -> Param(name)

    // Multi-wildcard: ** or **name
    "**" -> MultiWildcard(None)
    "**" <> name -> MultiWildcard(Some(name))

    // Extension pattern: *.ext or *.{ext1,ext2}
    "*." <> ext_pattern -> parse_extension_pattern(ext_pattern)

    // Single wildcard: * or *name
    "*" -> SingleWildcard(None)
    "*" <> name -> SingleWildcard(Some(name))

    // Literal segment
    _ -> Literal(segment)
  }
}

/// Parse extension pattern from the part after "*."
///
/// Handles both single extensions (*.jpg) and multiple extensions (*.{jpg,png}).
fn parse_extension_pattern(ext_pattern: String) -> Segment {
  case string.starts_with(ext_pattern, "{") {
    True -> parse_brace_extensions(ext_pattern)
    False -> ExtensionPattern([ext_pattern])
  }
}

/// Parse brace-delimited extensions: {jpg,png,gif}
///
/// Extracts the comma-separated extensions from inside the braces,
/// trimming whitespace from each extension.
///
/// ## Example
///
/// ```gleam
/// parse_brace_extensions("{jpg, png, gif}")
/// // ExtensionPattern(["jpg", "png", "gif"])
/// ```
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

  ExtensionPattern(extensions)
}
