//// Tests for dream/router/trie module.

import dream/router/trie.{
  ExtensionPattern, Literal, LiteralExtension, Match, MultiWildcard, Param,
  SingleWildcard,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("trie", [
    literal_extension_tests(),
    shared_child_tests(),
    multi_wildcard_tests(),
    routes_tests(),
  ])
}

fn literal_extension_tests() -> UnitNode {
  group("literal extension segments", [
    it("keeps two methods on the same literal extension segment", fn() {
      // Arrange
      let segments = [LiteralExtension("products", ["json", "xml"])]
      let routes =
        trie.new()
        |> trie.insert("GET", segments, "list products")
        |> trie.insert("POST", segments, "create product")

      // Act
      let result = trie.lookup(routes, "POST", ["products.xml"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match(route: "create product", params: [])))
      |> or_fail_with("POST products.xml should find the POST route")
    }),
    it("finds the second of two literal extension segments", fn() {
      // Arrange
      let routes =
        trie.new()
        |> trie.insert("GET", [LiteralExtension("reports", ["csv"])], "reports")
        |> trie.insert(
          "GET",
          [LiteralExtension("products", ["json"])],
          "products",
        )

      // Act
      let result = trie.lookup(routes, "GET", ["products.json"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match(route: "products", params: [])))
      |> or_fail_with("products.json should skip reports and find products")
    }),
    it(
      "tries the next literal extension segment when a deeper match fails",
      fn() {
        // Arrange
        let routes =
          trie.new()
          |> trie.insert(
            "GET",
            [LiteralExtension("data", ["json"]), Literal("summary")],
            "summary",
          )
          |> trie.insert(
            "GET",
            [LiteralExtension("data", ["json", "xml"]), Literal("detail")],
            "detail",
          )

        // Act
        let result = trie.lookup(routes, "GET", ["data.json", "detail"])

        // Assert
        result
        |> should()
        |> be_equal(Some(Match(route: "detail", params: [])))
        |> or_fail_with("data.json/detail should find the second segment")
      },
    ),
  ])
}

fn shared_child_tests() -> UnitNode {
  group("routes that share a child node", [
    it("keeps two methods on the same parameter segment", fn() {
      // Arrange
      let segments = [Literal("users"), Param("id")]
      let routes =
        trie.new()
        |> trie.insert("GET", segments, "show user")
        |> trie.insert("DELETE", segments, "delete user")

      // Act
      let result = trie.lookup(routes, "DELETE", ["users", "7"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match(route: "delete user", params: [#("id", "7")])))
      |> or_fail_with("DELETE /users/7 should find the DELETE route")
    }),
    it("keeps two methods on the same single wildcard segment", fn() {
      // Arrange
      let segments = [Literal("files"), SingleWildcard(None)]
      let routes =
        trie.new()
        |> trie.insert("GET", segments, "read file")
        |> trie.insert("DELETE", segments, "delete file")

      // Act
      let result = trie.lookup(routes, "DELETE", ["files", "a.txt"])

      // Assert
      result
      |> should()
      |> be_equal(
        Some(Match(route: "delete file", params: [#("wildcard", "a.txt")])),
      )
      |> or_fail_with("DELETE /files/a.txt should find the DELETE route")
    }),
    it("keeps two methods on the same multi wildcard segment", fn() {
      // Arrange
      let segments = [Literal("static"), MultiWildcard(Some("rest"))]
      let routes =
        trie.new()
        |> trie.insert("GET", segments, "read static")
        |> trie.insert("HEAD", segments, "check static")

      // Act
      let result = trie.lookup(routes, "HEAD", ["static", "css", "app.css"])

      // Assert
      result
      |> should()
      |> be_equal(
        Some(Match(route: "check static", params: [#("rest", "css/app.css")])),
      )
      |> or_fail_with("HEAD /static/css/app.css should find the HEAD route")
    }),
    it("keeps two methods on the same extension pattern segment", fn() {
      // Arrange
      let segments = [Literal("assets"), ExtensionPattern(["css"])]
      let routes =
        trie.new()
        |> trie.insert("GET", segments, "read stylesheet")
        |> trie.insert("HEAD", segments, "check stylesheet")

      // Act
      let result = trie.lookup(routes, "HEAD", ["assets", "app.css"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match(route: "check stylesheet", params: [])))
      |> or_fail_with("HEAD /assets/app.css should find the HEAD route")
    }),
  ])
}

fn multi_wildcard_tests() -> UnitNode {
  group("multi wildcard", [
    it("matches the bare prefix with an empty path parameter", fn() {
      // Arrange
      let routes =
        trie.new()
        |> trie.insert(
          "GET",
          [Literal("public"), MultiWildcard(None)],
          "public",
        )

      // Act
      let result = trie.lookup(routes, "GET", ["public"])

      // Assert
      result
      |> should()
      |> be_equal(Some(Match(route: "public", params: [#("path", "")])))
      |> or_fail_with("/public should match /public/** with an empty path")
    }),
  ])
}

fn routes_tests() -> UnitNode {
  group("routes", [
    it("lists no routes for an empty trie", fn() {
      // Arrange
      let empty = trie.new()

      // Act
      let result = trie.routes(empty)

      // Assert
      result
      |> should()
      |> be_equal([])
      |> or_fail_with("an empty trie should list no routes")
    }),
    it("lists each route with its method, segments and value", fn() {
      // Arrange
      let routes =
        trie.new()
        |> trie.insert("GET", [], "root")
        |> trie.insert("GET", [Literal("users"), Param("id")], "show user")
        |> trie.insert("DELETE", [Literal("users"), Param("id")], "delete user")
        |> trie.insert(
          "GET",
          [LiteralExtension("products", ["json", "xml"])],
          "products",
        )
        |> trie.insert(
          "GET",
          [Literal("files"), SingleWildcard(Some("file"))],
          "file",
        )
        |> trie.insert(
          "GET",
          [Literal("static"), MultiWildcard(None)],
          "static",
        )
        |> trie.insert(
          "GET",
          [Literal("images"), ExtensionPattern(["png"])],
          "image",
        )

      // Act
      let result = list.sort(trie.routes(routes), by_route_value)

      // Assert
      result
      |> should()
      |> be_equal([
        #("DELETE", [Literal("users"), Param("id")], "delete user"),
        #("GET", [Literal("files"), SingleWildcard(Some("file"))], "file"),
        #("GET", [Literal("images"), ExtensionPattern(["png"])], "image"),
        #("GET", [LiteralExtension("products", ["json", "xml"])], "products"),
        #("GET", [], "root"),
        #("GET", [Literal("users"), Param("id")], "show user"),
        #("GET", [Literal("static"), MultiWildcard(None)], "static"),
      ])
      |> or_fail_with("routes should list every route of the trie")
    }),
    it("lists a shared parameter with the name of the first route", fn() {
      // Arrange
      let routes =
        trie.new()
        |> trie.insert("GET", [Literal("users"), Param("id")], "show user")
        |> trie.insert(
          "GET",
          [Literal("users"), Param("user_id"), Literal("posts")],
          "user posts",
        )

      // Act
      let result = list.sort(trie.routes(routes), by_route_value)

      // Assert
      result
      |> should()
      |> be_equal([
        #("GET", [Literal("users"), Param("id")], "show user"),
        #(
          "GET",
          [Literal("users"), Param("id"), Literal("posts")],
          "user posts",
        ),
      ])
      |> or_fail_with("the shared parameter node should keep the name id")
    }),
  ])
}

fn by_route_value(
  first: #(String, List(trie.Segment), String),
  second: #(String, List(trie.Segment), String),
) {
  string.compare(first.2, second.2)
}
