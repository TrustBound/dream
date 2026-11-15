//// Examples for the doc comments of `dream/router/parser`.

import dream/router/parser.{parse_pattern}
import dream/router/trie.{type Segment}

pub fn module_examples() -> List(List(Segment)) {
  let users = parse_pattern("/users/:id")
  // [Literal("users"), Param("id")]

  let files = parse_pattern("/files/**path")
  // [Literal("files"), MultiWildcard(Some("path"))]

  let images = parse_pattern("/images/*.{jpg,png}")
  // [Literal("images"), ExtensionPattern(["jpg", "png"])]

  [users, files, images]
}

pub fn parse_pattern_examples() -> List(List(Segment)) {
  // Simple literal path
  let users = parse_pattern("/users")
  // [Literal("users")]

  // Parameter capture
  let user = parse_pattern("/users/:id")
  // [Literal("users"), Param("id")]

  // Multi-segment wildcard
  let files = parse_pattern("/public/**filepath")
  // [Literal("public"), MultiWildcard(Some("filepath"))]

  // Extension matching
  let images = parse_pattern("/images/*.{jpg,png}")
  // [Literal("images"), ExtensionPattern(["jpg", "png"])]

  [users, user, files, images]
}

pub fn brace_extensions() -> List(Segment) {
  // Spaces after the commas are trimmed
  parse_pattern("/images/*.{jpg, png, gif}")
  // [Literal("images"), ExtensionPattern(["jpg", "png", "gif"])]
}
