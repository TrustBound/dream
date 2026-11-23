//// Tests for dream/router/parser module.

import dream/router/parser
import dream/router/trie.{
  ExtensionPattern, Literal, MultiWildcard, Param, SingleWildcard,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/option.{None, Some}

pub fn tests() -> TestSuite {
  describe("parser", [
    static_path_tests(),
    parameter_tests(),
    wildcard_tests(),
    extension_pattern_tests(),
    complex_pattern_tests(),
    edge_case_tests(),
    unclosed_brace_tests(),
  ])
}

fn static_path_tests() -> UnitNode {
  group("static paths", [
    it("parses single static segment", fn() {
      // Arrange
      let pattern = "/users"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("users")])
      |> or_fail_with("Should parse /users")
    }),
    it("parses multiple static segments", fn() {
      // Arrange
      let pattern = "/api/v1/users"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("api"), Literal("v1"), Literal("users")])
      |> or_fail_with("Should parse /api/v1/users")
    }),
    it("parses root path as empty list", fn() {
      // Arrange
      let pattern = "/"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([])
      |> or_fail_with("Root path should be empty list")
    }),
  ])
}

fn parameter_tests() -> UnitNode {
  group("parameters", [
    it("parses single param", fn() {
      // Arrange
      let pattern = "/users/:id"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("users"), Param("id")])
      |> or_fail_with("Should parse /users/:id")
    }),
    it("parses multiple params", fn() {
      // Arrange
      let pattern = "/users/:user_id/posts/:post_id"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([
        Literal("users"),
        Param("user_id"),
        Literal("posts"),
        Param("post_id"),
      ])
      |> or_fail_with("Should parse multiple params")
    }),
    it("parses param only path", fn() {
      // Arrange
      let pattern = "/:id"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Param("id")])
      |> or_fail_with("Should parse /:id")
    }),
  ])
}

fn wildcard_tests() -> UnitNode {
  group("wildcards", [
    it("parses anonymous single wildcard", fn() {
      // Arrange
      let pattern = "/files/*"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("files"), SingleWildcard(None)])
      |> or_fail_with("Should parse /files/*")
    }),
    it("parses named single wildcard", fn() {
      // Arrange
      let pattern = "/files/*filename"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("files"), SingleWildcard(Some("filename"))])
      |> or_fail_with("Should parse /files/*filename")
    }),
    it("parses anonymous multi wildcard", fn() {
      // Arrange
      let pattern = "/public/**"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("public"), MultiWildcard(None)])
      |> or_fail_with("Should parse /public/**")
    }),
    it("parses named multi wildcard", fn() {
      // Arrange
      let pattern = "/public/**filepath"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("public"), MultiWildcard(Some("filepath"))])
      |> or_fail_with("Should parse /public/**filepath")
    }),
  ])
}

fn extension_pattern_tests() -> UnitNode {
  group("extension patterns", [
    it("parses single extension", fn() {
      // Arrange
      let pattern = "/css/*.css"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("css"), ExtensionPattern(["css"])])
      |> or_fail_with("Should parse /css/*.css")
    }),
    it("parses brace extensions", fn() {
      // Arrange
      let pattern = "/images/*.{jpg,png,gif}"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
      |> or_fail_with("Should parse /images/*.{jpg,png,gif}")
    }),
    it("parses brace extensions with spaces", fn() {
      // Arrange
      let pattern = "/images/*.{jpg, png, gif}"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
      |> or_fail_with("Should parse with spaces")
    }),
  ])
}

fn complex_pattern_tests() -> UnitNode {
  group("complex patterns", [
    it("parses pattern with all types", fn() {
      // Arrange
      let pattern = "/api/:version/users/:id/files/**path"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([
        Literal("api"),
        Param("version"),
        Literal("users"),
        Param("id"),
        Literal("files"),
        MultiWildcard(Some("path")),
      ])
      |> or_fail_with("Should parse complex pattern")
    }),
    it("parses multiple wildcards", fn() {
      // Arrange
      let pattern = "/*/files/*name"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([
        SingleWildcard(None),
        Literal("files"),
        SingleWildcard(Some("name")),
      ])
      |> or_fail_with("Should parse multiple wildcards")
    }),
    it("parses extension in middle of path", fn() {
      // Arrange
      let pattern = "/photos/**/*.{jpg,png}"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([
        Literal("photos"),
        MultiWildcard(None),
        ExtensionPattern(["jpg", "png"]),
      ])
      |> or_fail_with("Should parse extension in middle")
    }),
  ])
}

fn edge_case_tests() -> UnitNode {
  group("edge cases", [
    it("ignores trailing slash", fn() {
      // Arrange
      let pattern = "/users/"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("users")])
      |> or_fail_with("Should ignore trailing slash")
    }),
    it("handles multiple slashes", fn() {
      // Arrange
      let pattern = "///users///posts///"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("users"), Literal("posts")])
      |> or_fail_with("Should handle multiple slashes")
    }),
    it("handles no leading slash", fn() {
      // Arrange
      let pattern = "users"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("users")])
      |> or_fail_with("Should handle no leading slash")
    }),
  ])
}

fn unclosed_brace_tests() -> UnitNode {
  group("unclosed brace", [
    it("keeps a segment with an unclosed brace as a literal", fn() {
      // Arrange
      let pattern = "/files/data.{json"

      // Act
      let result = parser.parse_pattern(pattern)

      // Assert
      result
      |> should()
      |> be_equal([Literal("files"), Literal("data.{json")])
      |> or_fail_with("data.{json has no closing brace, so it is a literal")
    }),
  ])
}
