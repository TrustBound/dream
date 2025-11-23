import dream/router/parser
import dream/router/trie.{
  ExtensionPattern, Literal, MultiWildcard, Param, SingleWildcard,
}
import gleam/option.{None, Some}
import gleeunit/should

// ============================================================================
// Static Path Tests
// ============================================================================

pub fn parse_single_static_segment_test() {
  parser.parse_pattern("/users")
  |> should.equal([Literal("users")])
}

pub fn parse_multiple_static_segments_test() {
  parser.parse_pattern("/api/v1/users")
  |> should.equal([Literal("api"), Literal("v1"), Literal("users")])
}

pub fn parse_root_path_test() {
  parser.parse_pattern("/")
  |> should.equal([])
}

// ============================================================================
// Parameter Tests
// ============================================================================

pub fn parse_single_param_test() {
  parser.parse_pattern("/users/:id")
  |> should.equal([Literal("users"), Param("id")])
}

pub fn parse_multiple_params_test() {
  parser.parse_pattern("/users/:user_id/posts/:post_id")
  |> should.equal([
    Literal("users"),
    Param("user_id"),
    Literal("posts"),
    Param("post_id"),
  ])
}

pub fn parse_param_only_test() {
  parser.parse_pattern("/:id")
  |> should.equal([Param("id")])
}

// ============================================================================
// Wildcard Tests
// ============================================================================

pub fn parse_anonymous_single_wildcard_test() {
  parser.parse_pattern("/files/*")
  |> should.equal([Literal("files"), SingleWildcard(None)])
}

pub fn parse_named_single_wildcard_test() {
  parser.parse_pattern("/files/*filename")
  |> should.equal([Literal("files"), SingleWildcard(Some("filename"))])
}

pub fn parse_anonymous_multi_wildcard_test() {
  parser.parse_pattern("/public/**")
  |> should.equal([Literal("public"), MultiWildcard(None)])
}

pub fn parse_named_multi_wildcard_test() {
  parser.parse_pattern("/public/**filepath")
  |> should.equal([Literal("public"), MultiWildcard(Some("filepath"))])
}

// ============================================================================
// Extension Pattern Tests
// ============================================================================

pub fn parse_single_extension_test() {
  parser.parse_pattern("/css/*.css")
  |> should.equal([Literal("css"), ExtensionPattern(["css"])])
}

pub fn parse_brace_extensions_test() {
  parser.parse_pattern("/images/*.{jpg,png,gif}")
  |> should.equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
}

pub fn parse_brace_extensions_with_spaces_test() {
  parser.parse_pattern("/images/*.{jpg, png, gif}")
  |> should.equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
}

// ============================================================================
// Complex Pattern Tests
// ============================================================================

pub fn parse_complex_pattern_with_all_types_test() {
  parser.parse_pattern("/api/:version/users/:id/files/**path")
  |> should.equal([
    Literal("api"),
    Param("version"),
    Literal("users"),
    Param("id"),
    Literal("files"),
    MultiWildcard(Some("path")),
  ])
}

pub fn parse_multiple_wildcards_test() {
  parser.parse_pattern("/*/files/*name")
  |> should.equal([
    SingleWildcard(None),
    Literal("files"),
    SingleWildcard(Some("name")),
  ])
}

pub fn parse_extension_in_middle_test() {
  parser.parse_pattern("/photos/**/*.{jpg,png}")
  |> should.equal([
    Literal("photos"),
    MultiWildcard(None),
    ExtensionPattern(["jpg", "png"]),
  ])
}

// ============================================================================
// Edge Case Tests
// ============================================================================

pub fn parse_trailing_slash_ignored_test() {
  parser.parse_pattern("/users/")
  |> should.equal([Literal("users")])
}

pub fn parse_multiple_slashes_test() {
  parser.parse_pattern("///users///posts///")
  |> should.equal([Literal("users"), Literal("posts")])
}

pub fn parse_no_leading_slash_test() {
  parser.parse_pattern("users")
  |> should.equal([Literal("users")])
}
