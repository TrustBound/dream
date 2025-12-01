//// Tests for dream/router module.

import dream/http/request.{Get, Patch, Post, Put}
import dream/router.{find_route, route, router, stream_route}
import dream_test/assertions/should.{
  be_none, be_some, be_true, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{literal_handler, param_handler, test_handler}
import fixtures/request as test_request
import matchers/extract_route_params.{extract_route_params}
import matchers/extract_streaming_flag.{extract_streaming_flag}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("router", [
    streaming_flag_tests(),
    basic_route_tests(),
    parameter_tests(),
    wildcard_tests(),
    extension_pattern_tests(),
    precedence_tests(),
    method_matching_tests(),
    middleware_chain_tests(),
    regression_tests(),
  ])
}

fn streaming_flag_tests() -> UnitTest {
  describe("streaming flag", [
    it("stream_route with POST sets streaming to true", fn() {
      let test_router =
        router()
        |> stream_route(Post, "/upload", test_handler, [])

      find_route(test_router, test_request.create_request(Post, "/upload"))
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("stream_route with PUT sets streaming to true", fn() {
      let test_router =
        router()
        |> stream_route(Put, "/upload", test_handler, [])

      find_route(test_router, test_request.create_request(Put, "/upload"))
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("stream_route with PATCH sets streaming to true", fn() {
      let test_router =
        router()
        |> stream_route(Patch, "/upload", test_handler, [])

      find_route(test_router, test_request.create_request(Patch, "/upload"))
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("regular route sets streaming to false", fn() {
      let test_router =
        router()
        |> route(Post, "/upload", test_handler, [])

      find_route(test_router, test_request.create_request(Post, "/upload"))
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> equal(False)
      |> or_fail_with("streaming flag should be false")
    }),
  ])
}

fn basic_route_tests() -> UnitTest {
  describe("basic routing", [
    it("empty router returns None", fn() {
      find_route(router(), test_request.create_request(Get, "/users"))
      |> should()
      |> be_none()
      |> or_fail_with("Empty router should return None")
    }),
    it("matches single literal route", fn() {
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users"))
      |> should()
      |> be_some()
      |> or_fail_with("Should match /users route")
    }),
    it("matches GET on path with multiple methods", fn() {
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
        |> route(Post, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users"))
      |> should()
      |> be_some()
      |> or_fail_with("Should match GET /users")
    }),
    it("matches POST on path with multiple methods", fn() {
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
        |> route(Post, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Post, "/users"))
      |> should()
      |> be_some()
      |> or_fail_with("Should match POST /users")
    }),
  ])
}

fn parameter_tests() -> UnitTest {
  describe("parameter extraction", [
    it("extracts single parameter", fn() {
      let test_router =
        router()
        |> route(Get, "/users/:id", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users/123"))
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Should extract id parameter")
    }),
    it("extracts multiple parameters in path order", fn() {
      let test_router =
        router()
        |> route(Get, "/users/:user_id/posts/:post_id", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/users/123/posts/456"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("user_id", "123"), #("post_id", "456")])
      |> or_fail_with("Should extract params in path order")
    }),
    it("extracts parameter with special characters", fn() {
      let test_router =
        router()
        |> route(Get, "/users/:slug", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/users/john-doe"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("slug", "john-doe")])
      |> or_fail_with("Should extract slug with hyphen")
    }),
    it("extracts numeric parameter", fn() {
      let test_router =
        router()
        |> route(Get, "/items/:count", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/items/999"))
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("count", "999")])
      |> or_fail_with("Should extract numeric value as string")
    }),
  ])
}

fn wildcard_tests() -> UnitTest {
  describe("wildcard routes", [
    it("matches wildcard single segment", fn() {
      let test_router =
        router()
        |> route(Get, "/files/*path", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/files/document"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("path", "document")])
      |> or_fail_with("Should capture single segment")
    }),
    it("matches multi-wildcard for multiple segments", fn() {
      let test_router =
        router()
        |> route(Get, "/files/**path", test_handler, [])

      // Use ** (multi-wildcard) to capture multiple path segments
      find_route(
        test_router,
        test_request.create_request(Get, "/files/dir/subdir/file.txt"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("path", "dir/subdir/file.txt")])
      |> or_fail_with("Should capture full path")
    }),
    it("wildcard with extension preserves extension", fn() {
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/files/document.pdf"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("filename", "document.pdf")])
      |> or_fail_with("Wildcard should capture full segment")
    }),
    it("wildcard with multiple dots", fn() {
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/files/file.backup.tar.gz"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("filename", "file.backup.tar.gz")])
      |> or_fail_with("Should capture full filename with multiple dots")
    }),
    it("wildcard with hidden files", fn() {
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/files/.hidden"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("filename", ".hidden")])
      |> or_fail_with("Should capture hidden file")
    }),
  ])
}

fn extension_pattern_tests() -> UnitTest {
  describe("extension patterns", [
    it("matches literal extension pattern for json", fn() {
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/products.json"),
      )
      |> should()
      |> be_some()
      |> or_fail_with("Should match products.json")
    }),
    it("matches literal extension pattern for xml", fn() {
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/products.xml"))
      |> should()
      |> be_some()
      |> or_fail_with("Should match products.xml")
    }),
    it("does not match unlisted extension", fn() {
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/products.csv"))
      |> should()
      |> be_none()
      |> or_fail_with("Should not match products.csv")
    }),
    it("extension pattern on wildcard", fn() {
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/images/photo.jpg"),
      )
      |> should()
      |> be_some()
      |> or_fail_with("Should match *.jpg pattern")
    }),
    it("extension pattern on wildcard png", fn() {
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/images/icon.png"),
      )
      |> should()
      |> be_some()
      |> or_fail_with("Should match *.png pattern")
    }),
    it("param preserves extension in value", fn() {
      let test_router =
        router()
        |> route(Get, "/products/:id", param_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/products/1.json"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "1.json")])
      |> or_fail_with("Param should preserve extension for format detection")
    }),
  ])
}

fn precedence_tests() -> UnitTest {
  describe("route precedence", [
    it("literal route takes precedence over param", fn() {
      let test_router =
        router()
        |> route(Get, "/users/new", literal_handler, [])
        |> route(Get, "/users/:id", param_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users/new"))
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([])
      |> or_fail_with("Literal route should have no params")
    }),
    it("param route matches non-literal", fn() {
      let test_router =
        router()
        |> route(Get, "/users/new", literal_handler, [])
        |> route(Get, "/users/:id", param_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users/123"))
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Param route should capture id")
    }),
    it("extension pattern takes precedence over param route", fn() {
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/images/photo.jpg"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([])
      |> or_fail_with("Extension pattern should match with no params")
    }),
    it("param route matches non-pattern extensions", fn() {
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/images/document.pdf"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("name", "document.pdf")])
      |> or_fail_with("Param route should capture .pdf with extension")
    }),
  ])
}

fn method_matching_tests() -> UnitTest {
  describe("method matching", [
    it("does not match wrong method", fn() {
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Post, "/users"))
      |> should()
      |> be_none()
      |> or_fail_with("POST should not match GET route")
    }),
    it("each method has its own route", fn() {
      let test_router =
        router()
        |> route(Get, "/items", test_handler, [])
        |> route(Post, "/items", test_handler, [])
        |> route(Put, "/items/:id", test_handler, [])

      find_route(test_router, test_request.create_request(Put, "/items/123"))
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("PUT should match with id param")
    }),
  ])
}

fn middleware_chain_tests() -> UnitTest {
  describe("middleware chain", [
    it("route with empty middleware list works", fn() {
      let test_router =
        router()
        |> route(Get, "/simple", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/simple"))
      |> should()
      |> be_some()
      |> or_fail_with("Should match route with empty middleware")
    }),
  ])
}

fn regression_tests() -> UnitTest {
  describe("regression tests", [
    it("does not match unregistered path", fn() {
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/products"))
      |> should()
      |> be_none()
      |> or_fail_with("Should not match unregistered path")
    }),
    it("trailing slash is treated as same route", fn() {
      // Router normalizes paths by filtering empty segments
      // So /users/ is treated the same as /users
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])

      find_route(test_router, test_request.create_request(Get, "/users/"))
      |> should()
      |> be_some()
      |> or_fail_with("Trailing slash should match same route")
    }),
    it("matches nested paths", fn() {
      let test_router =
        router()
        |> route(Get, "/api/v1/users/:id/posts", test_handler, [])

      find_route(
        test_router,
        test_request.create_request(Get, "/api/v1/users/123/posts"),
      )
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Should match deeply nested route")
    }),
  ])
}
