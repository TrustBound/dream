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
//// ### Parse patterns <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_parser.gleam#L6-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn module_examples() -> List(List(Segment)) {
////   let users = parse_pattern("/users/:id")
////   // [Literal("users"), Param("id")]
////
////   let files = parse_pattern("/files/**path")
////   // [Literal("files"), MultiWildcard(Some("path"))]
////
////   let images = parse_pattern("/images/*.{jpg,png}")
////   // [Literal("images"), ExtensionPattern(["jpg", "png"])]
////
////   [users, files, images]
//// }
//// ```
////
//// ## Pattern Precedence
////
//// When multiple routes could match the same path, the most specific wins:
//// 1. Literal segments (highest priority)
//// 2. Parameters
//// 3. Single wildcards
//// 4. Multi-segment wildcards (lowest priority)
////
//// A segment with an extension, such as `photo.jpg`, uses a different order:
//// literal, extension pattern, single wildcard, multi-segment wildcard, and
//// parameter last.

import dream/router/trie.{
  type Segment, ExtensionPattern, Literal, LiteralExtension, MultiWildcard,
  Param, SingleWildcard,
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
/// ### Parse each kind of segment <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_parser.gleam#L19-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn parse_pattern_examples() -> List(List(Segment)) {
///   // Simple literal path
///   let users = parse_pattern("/users")
///   // [Literal("users")]
///
///   // Parameter capture
///   let user = parse_pattern("/users/:id")
///   // [Literal("users"), Param("id")]
///
///   // Multi-segment wildcard
///   let files = parse_pattern("/public/**filepath")
///   // [Literal("public"), MultiWildcard(Some("filepath"))]
///
///   // Extension matching
///   let images = parse_pattern("/images/*.{jpg,png}")
///   // [Literal("images"), ExtensionPattern(["jpg", "png"])]
///
///   [users, user, files, images]
/// }
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
fn is_non_empty_segment(segment: String) -> Bool {
  segment != ""
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
    "*." <> extension_pattern -> parse_extension_pattern(extension_pattern)

    // Single wildcard: * or *name
    "*" -> SingleWildcard(None)
    "*" <> name -> SingleWildcard(Some(name))

    // Check for literal with brace extension pattern: name.{ext1,ext2}
    _ -> parse_literal_or_extension(segment)
  }
}

/// Parse a segment that might be a literal or a literal with extension pattern
///
/// Handles patterns like "products.{json,xml}" which should match
/// "products.json" or "products.xml"
fn parse_literal_or_extension(segment: String) -> Segment {
  case string.split_once(segment, ".{") {
    Ok(#(base_name, rest)) -> {
      // Found a brace pattern like "products.{json,xml}"
      // rest is "json,xml}" - need to parse extensions
      case string.ends_with(rest, "}") {
        True -> {
          let inner = string.drop_end(rest, 1)
          let extensions =
            inner
            |> string.split(",")
            |> list.map(string.trim)
          LiteralExtension(base_name, extensions)
        }
        False -> Literal(segment)
      }
    }
    Error(_) -> Literal(segment)
  }
}

/// Parse extension pattern from the part after "*."
///
/// Handles both single extensions (*.jpg) and multiple extensions (*.{jpg,png}).
fn parse_extension_pattern(extension_pattern: String) -> Segment {
  case string.starts_with(extension_pattern, "{") {
    True -> parse_brace_extensions(extension_pattern)
    False -> ExtensionPattern([extension_pattern])
  }
}

/// Parse brace-delimited extensions: {jpg,png,gif}
///
/// Extracts the comma-separated extensions from inside the braces,
/// trimming whitespace from each extension.
///
/// ## Example
///
/// ### Trim spaces in extensions <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_parser.gleam#L39-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn brace_extensions() -> List(Segment) {
///   // Spaces after the commas are trimmed
///   parse_pattern("/images/*.{jpg, png, gif}")
///   // [Literal("images"), ExtensionPattern(["jpg", "png", "gif"])]
/// }
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
