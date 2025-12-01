//// Tests for dream/router/parser module.

import dream/router/parser
import dream/router/trie.{
  ExtensionPattern, Literal, MultiWildcard, Param, SingleWildcard,
}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option.{None, Some}

pub fn tests() -> UnitTest {
  describe("parser", [
    static_path_tests(),
    parameter_tests(),
    wildcard_tests(),
    extension_pattern_tests(),
    complex_pattern_tests(),
    edge_case_tests(),
  ])
}

fn static_path_tests() -> UnitTest {
  describe("static paths", [
    it("parses single static segment", fn() {
      parser.parse_pattern("/users")
      |> should()
      |> equal([Literal("users")])
      |> or_fail_with("Should parse /users")
    }),
    it("parses multiple static segments", fn() {
      parser.parse_pattern("/api/v1/users")
      |> should()
      |> equal([Literal("api"), Literal("v1"), Literal("users")])
      |> or_fail_with("Should parse /api/v1/users")
    }),
    it("parses root path as empty list", fn() {
      parser.parse_pattern("/")
      |> should()
      |> equal([])
      |> or_fail_with("Root path should be empty list")
    }),
  ])
}

fn parameter_tests() -> UnitTest {
  describe("parameters", [
    it("parses single param", fn() {
      parser.parse_pattern("/users/:id")
      |> should()
      |> equal([Literal("users"), Param("id")])
      |> or_fail_with("Should parse /users/:id")
    }),
    it("parses multiple params", fn() {
      parser.parse_pattern("/users/:user_id/posts/:post_id")
      |> should()
      |> equal([
        Literal("users"),
        Param("user_id"),
        Literal("posts"),
        Param("post_id"),
      ])
      |> or_fail_with("Should parse multiple params")
    }),
    it("parses param only path", fn() {
      parser.parse_pattern("/:id")
      |> should()
      |> equal([Param("id")])
      |> or_fail_with("Should parse /:id")
    }),
  ])
}

fn wildcard_tests() -> UnitTest {
  describe("wildcards", [
    it("parses anonymous single wildcard", fn() {
      parser.parse_pattern("/files/*")
      |> should()
      |> equal([Literal("files"), SingleWildcard(None)])
      |> or_fail_with("Should parse /files/*")
    }),
    it("parses named single wildcard", fn() {
      parser.parse_pattern("/files/*filename")
      |> should()
      |> equal([Literal("files"), SingleWildcard(Some("filename"))])
      |> or_fail_with("Should parse /files/*filename")
    }),
    it("parses anonymous multi wildcard", fn() {
      parser.parse_pattern("/public/**")
      |> should()
      |> equal([Literal("public"), MultiWildcard(None)])
      |> or_fail_with("Should parse /public/**")
    }),
    it("parses named multi wildcard", fn() {
      parser.parse_pattern("/public/**filepath")
      |> should()
      |> equal([Literal("public"), MultiWildcard(Some("filepath"))])
      |> or_fail_with("Should parse /public/**filepath")
    }),
  ])
}

fn extension_pattern_tests() -> UnitTest {
  describe("extension patterns", [
    it("parses single extension", fn() {
      parser.parse_pattern("/css/*.css")
      |> should()
      |> equal([Literal("css"), ExtensionPattern(["css"])])
      |> or_fail_with("Should parse /css/*.css")
    }),
    it("parses brace extensions", fn() {
      parser.parse_pattern("/images/*.{jpg,png,gif}")
      |> should()
      |> equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
      |> or_fail_with("Should parse /images/*.{jpg,png,gif}")
    }),
    it("parses brace extensions with spaces", fn() {
      parser.parse_pattern("/images/*.{jpg, png, gif}")
      |> should()
      |> equal([Literal("images"), ExtensionPattern(["jpg", "png", "gif"])])
      |> or_fail_with("Should parse with spaces")
    }),
  ])
}

fn complex_pattern_tests() -> UnitTest {
  describe("complex patterns", [
    it("parses pattern with all types", fn() {
      parser.parse_pattern("/api/:version/users/:id/files/**path")
      |> should()
      |> equal([
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
      parser.parse_pattern("/*/files/*name")
      |> should()
      |> equal([
        SingleWildcard(None),
        Literal("files"),
        SingleWildcard(Some("name")),
      ])
      |> or_fail_with("Should parse multiple wildcards")
    }),
    it("parses extension in middle of path", fn() {
      parser.parse_pattern("/photos/**/*.{jpg,png}")
      |> should()
      |> equal([
        Literal("photos"),
        MultiWildcard(None),
        ExtensionPattern(["jpg", "png"]),
      ])
      |> or_fail_with("Should parse extension in middle")
    }),
  ])
}

fn edge_case_tests() -> UnitTest {
  describe("edge cases", [
    it("ignores trailing slash", fn() {
      parser.parse_pattern("/users/")
      |> should()
      |> equal([Literal("users")])
      |> or_fail_with("Should ignore trailing slash")
    }),
    it("handles multiple slashes", fn() {
      parser.parse_pattern("///users///posts///")
      |> should()
      |> equal([Literal("users"), Literal("posts")])
      |> or_fail_with("Should handle multiple slashes")
    }),
    it("handles no leading slash", fn() {
      parser.parse_pattern("users")
      |> should()
      |> equal([Literal("users")])
      |> or_fail_with("Should handle no leading slash")
    }),
  ])
}
