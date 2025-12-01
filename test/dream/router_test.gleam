//// Tests for dream/router module.

import dream/context
import dream/http/header.{Header}
import dream/http/request.{Get, Patch, Post, Put}
import dream/http/response.{Response}
import dream/router.{
  build_controller_chain, find_route, route, router, stream_route,
}
import dream_test/assertions/should.{
  be_none, be_some, be_true, equal, have_length, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{literal_handler, param_handler, test_handler}
import fixtures/request as test_request
import matchers/extract_header_name_at_index.{extract_header_name_at_index}
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
    parameter_remapping_tests(),
    extension_stripping_tests(),
    regression_tests(),
  ])
}

fn streaming_flag_tests() -> UnitTest {
  describe("streaming flag", [
    it("stream_route with POST sets streaming to true", fn() {
      // Arrange
      let test_router =
        router()
        |> stream_route(Post, "/upload", test_handler, [])
      let request = test_request.create_request(Post, "/upload")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("stream_route with PUT sets streaming to true", fn() {
      // Arrange
      let test_router =
        router()
        |> stream_route(Put, "/upload", test_handler, [])
      let request = test_request.create_request(Put, "/upload")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("stream_route with PATCH sets streaming to true", fn() {
      // Arrange
      let test_router =
        router()
        |> stream_route(Patch, "/upload", test_handler, [])
      let request = test_request.create_request(Patch, "/upload")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_streaming_flag()
      |> be_true()
      |> or_fail_with("streaming flag should be true")
    }),
    it("regular route sets streaming to false", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Post, "/upload", test_handler, [])
      let request = test_request.create_request(Post, "/upload")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router = router()
      let request = test_request.create_request(Get, "/users")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Empty router should return None")
    }),
    it("matches single literal route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
      let request = test_request.create_request(Get, "/users")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match /users route")
    }),
    it("matches GET on path with multiple methods", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
        |> route(Post, "/users", test_handler, [])
      let request = test_request.create_request(Get, "/users")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match GET /users")
    }),
    it("matches POST on path with multiple methods", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
        |> route(Post, "/users", test_handler, [])
      let request = test_request.create_request(Post, "/users")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match POST /users")
    }),
  ])
}

fn parameter_tests() -> UnitTest {
  describe("parameter extraction", [
    it("extracts single parameter", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id", test_handler, [])
      let request = test_request.create_request(Get, "/users/123")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Should extract id parameter")
    }),
    it("extracts multiple parameters in path order", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:user_id/posts/:post_id", test_handler, [])
      let request = test_request.create_request(Get, "/users/123/posts/456")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("user_id", "123"), #("post_id", "456")])
      |> or_fail_with("Should extract params in path order")
    }),
    it("extracts parameter with special characters", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:slug", test_handler, [])
      let request = test_request.create_request(Get, "/users/john-doe")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("slug", "john-doe")])
      |> or_fail_with("Should extract slug with hyphen")
    }),
    it("extracts numeric parameter", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/items/:count", test_handler, [])
      let request = test_request.create_request(Get, "/items/999")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*path", test_handler, [])
      let request = test_request.create_request(Get, "/files/document")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("path", "document")])
      |> or_fail_with("Should capture single segment")
    }),
    it("matches multi-wildcard for multiple segments", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/**path", test_handler, [])
      let request =
        test_request.create_request(Get, "/files/dir/subdir/file.txt")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("path", "dir/subdir/file.txt")])
      |> or_fail_with("Should capture full path")
    }),
    it("wildcard with extension preserves extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])
      let request = test_request.create_request(Get, "/files/document.pdf")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("filename", "document.pdf")])
      |> or_fail_with("Wildcard should capture full segment")
    }),
    it("wildcard with multiple dots", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])
      let request =
        test_request.create_request(Get, "/files/file.backup.tar.gz")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("filename", "file.backup.tar.gz")])
      |> or_fail_with("Should capture full filename with multiple dots")
    }),
    it("wildcard with hidden files", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*filename", test_handler, [])
      let request = test_request.create_request(Get, "/files/.hidden")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])
      let request = test_request.create_request(Get, "/products.json")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match products.json")
    }),
    it("matches literal extension pattern for xml", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])
      let request = test_request.create_request(Get, "/products.xml")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match products.xml")
    }),
    it("does not match unlisted extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products.{json,xml}", test_handler, [])
      let request = test_request.create_request(Get, "/products.csv")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should not match products.csv")
    }),
    it("extension pattern on wildcard", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
      let request = test_request.create_request(Get, "/images/photo.jpg")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match *.jpg pattern")
    }),
    it("extension pattern on wildcard png", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
      let request = test_request.create_request(Get, "/images/icon.png")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match *.png pattern")
    }),
    it("param preserves extension in value", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products/:id", param_handler, [])
      let request = test_request.create_request(Get, "/products/1.json")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/new", literal_handler, [])
        |> route(Get, "/users/:id", param_handler, [])
      let request = test_request.create_request(Get, "/users/new")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([])
      |> or_fail_with("Literal route should have no params")
    }),
    it("param route matches non-literal", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/new", literal_handler, [])
        |> route(Get, "/users/:id", param_handler, [])
      let request = test_request.create_request(Get, "/users/123")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Param route should capture id")
    }),
    it("extension pattern takes precedence over param route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])
      let request = test_request.create_request(Get, "/images/photo.jpg")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([])
      |> or_fail_with("Extension pattern should match with no params")
    }),
    it("param route matches non-pattern extensions", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])
      let request = test_request.create_request(Get, "/images/document.pdf")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
      let request = test_request.create_request(Post, "/users")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("POST should not match GET route")
    }),
    it("each method has its own route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/items", test_handler, [])
        |> route(Post, "/items", test_handler, [])
        |> route(Put, "/items/:id", test_handler, [])
      let request = test_request.create_request(Put, "/items/123")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
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
      // Arrange
      let test_router =
        router()
        |> route(Get, "/simple", test_handler, [])
      let request = test_request.create_request(Get, "/simple")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Should match route with empty middleware")
    }),
    it("build_controller_chain with no middleware returns controller", fn() {
      // Arrange
      let controller = build_controller_chain([], test_handler)
      let request = test_request.create_request(Get, "/")
      let app_context = context.AppContext("test")

      // Act
      let response = controller(request, app_context, router.EmptyServices)

      // Assert
      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("Controller should return 200")
    }),
    it("middleware wraps controller and adds header", fn() {
      // Arrange
      let add_header_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-Custom", "value"),
          ..response.headers
        ])
      }
      let controller =
        build_controller_chain(
          [router.Middleware(add_header_middleware)],
          test_handler,
        )
      let request = test_request.create_request(Get, "/")
      let app_context = context.AppContext("test")

      // Act
      let response = controller(request, app_context, router.EmptyServices)

      // Assert
      response.headers
      |> should()
      |> have_length(2)
      |> or_fail_with("Should have 2 headers")
    }),
    it("middleware adds X-Custom header", fn() {
      // Arrange
      let add_header_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-Custom", "value"),
          ..response.headers
        ])
      }
      let controller =
        build_controller_chain(
          [router.Middleware(add_header_middleware)],
          test_handler,
        )
      let request = test_request.create_request(Get, "/")
      let app_context = context.AppContext("test")

      // Act
      let response = controller(request, app_context, router.EmptyServices)

      // Assert
      response.headers
      |> should()
      |> extract_header_name_at_index(0)
      |> equal("X-Custom")
      |> or_fail_with("First header should be X-Custom")
    }),
    it("multiple middleware execute in order (first wraps second)", fn() {
      // Arrange
      let first_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-First", "1"),
          ..response.headers
        ])
      }
      let second_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-Second", "2"),
          ..response.headers
        ])
      }
      let controller =
        build_controller_chain(
          [
            router.Middleware(first_middleware),
            router.Middleware(second_middleware),
          ],
          test_handler,
        )
      let request = test_request.create_request(Get, "/")
      let app_context = context.AppContext("test")

      // Act
      let response = controller(request, app_context, router.EmptyServices)

      // Assert
      response.headers
      |> should()
      |> extract_header_name_at_index(0)
      |> equal("X-First")
      |> or_fail_with("First header should be X-First")
    }),
    it("second middleware header comes after first", fn() {
      // Arrange
      let first_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-First", "1"),
          ..response.headers
        ])
      }
      let second_middleware = fn(request, app_context, services, next) {
        let response = next(request, app_context, services)
        Response(..response, headers: [
          Header("X-Second", "2"),
          ..response.headers
        ])
      }
      let controller =
        build_controller_chain(
          [
            router.Middleware(first_middleware),
            router.Middleware(second_middleware),
          ],
          test_handler,
        )
      let request = test_request.create_request(Get, "/")
      let app_context = context.AppContext("test")

      // Act
      let response = controller(request, app_context, router.EmptyServices)

      // Assert
      response.headers
      |> should()
      |> extract_header_name_at_index(1)
      |> equal("X-Second")
      |> or_fail_with("Second header should be X-Second")
    }),
  ])
}

fn parameter_remapping_tests() -> UnitTest {
  describe("parameter remapping", [
    it(
      "routes with different param names at same position use correct names",
      fn() {
        // Arrange
        let test_router =
          router()
          |> route(Get, "/users/:id", param_handler, [])
          |> route(Get, "/users/:user_id/posts", test_handler, [])
        let request = test_request.create_request(Get, "/users/123")

        // Act
        let result = find_route(test_router, request)

        // Assert
        result
        |> should()
        |> be_some()
        |> extract_route_params()
        |> equal([#("id", "123")])
        |> or_fail_with("Should extract 'id' (route's declared param name)")
      },
    ),
    it("nested route extracts its own param name", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id", param_handler, [])
        |> route(Get, "/users/:user_id/posts", test_handler, [])
      let request = test_request.create_request(Get, "/users/123/posts")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("user_id", "123")])
      |> or_fail_with("Should extract 'user_id' (route's declared param name)")
    }),
    it("multiple params extract with correct names for first route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id/posts/:post_id", param_handler, [])
        |> route(Get, "/users/:user_id/comments/:comment_id", test_handler, [])
      let request = test_request.create_request(Get, "/users/123/posts/456")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123"), #("post_id", "456")])
      |> or_fail_with("Should extract id and post_id")
    }),
    it("multiple params extract with correct names for second route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users/:id/posts/:post_id", param_handler, [])
        |> route(Get, "/users/:user_id/comments/:comment_id", test_handler, [])
      let request = test_request.create_request(Get, "/users/123/comments/789")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("user_id", "123"), #("comment_id", "789")])
      |> or_fail_with("Should extract user_id and comment_id")
    }),
    it("wildcard routes extract with their own param names", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*file", param_handler, [])
        |> route(Get, "/images/*image", test_handler, [])
      let request = test_request.create_request(Get, "/files/document.pdf")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("file", "document.pdf")])
      |> or_fail_with("Should extract 'file' wildcard")
    }),
    it("second wildcard route extracts its own param name", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/files/*file", param_handler, [])
        |> route(Get, "/images/*image", test_handler, [])
      let request = test_request.create_request(Get, "/images/photo.jpg")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("image", "photo.jpg")])
      |> or_fail_with("Should extract 'image' wildcard")
    }),
  ])
}

fn extension_stripping_tests() -> UnitTest {
  describe("extension stripping", [
    it("literal route matches path with extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products", test_handler, [])
      let request = test_request.create_request(Get, "/products.json")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("/products.json should match /products route")
    }),
    it("literal route matches path with csv extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products", test_handler, [])
      let request = test_request.create_request(Get, "/products.csv")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("/products.csv should match /products route")
    }),
    it("literal route matches path without extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products", test_handler, [])
      let request = test_request.create_request(Get, "/products")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("/products should match /products route")
    }),
    it("param route matches path with extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products/:id", param_handler, [])
      let request = test_request.create_request(Get, "/products/1.json")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "1.json")])
      |> or_fail_with("Param should preserve extension for format detection")
    }),
    it("param route matches path with csv extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products/:id", param_handler, [])
      let request = test_request.create_request(Get, "/products/123.csv")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123.csv")])
      |> or_fail_with("Param should preserve csv extension")
    }),
    it("param route matches path without extension", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/products/:id", param_handler, [])
      let request = test_request.create_request(Get, "/products/456")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "456")])
      |> or_fail_with("Param should work without extension")
    }),
    it("nested route with extension on param", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/api/v1/users/:id", param_handler, [])
      let request = test_request.create_request(Get, "/api/v1/users/123.json")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123.json")])
      |> or_fail_with("Nested param should preserve extension")
    }),
    it("nested route with extension on last param", fn() {
      // Arrange
      let test_router =
        router()
        |> route(
          Get,
          "/api/v1/posts/:post_id/comments/:comment_id",
          param_handler,
          [],
        )
      let request =
        test_request.create_request(Get, "/api/v1/posts/456/comments/789.csv")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("post_id", "456"), #("comment_id", "789.csv")])
      |> or_fail_with("Last param should preserve extension")
    }),
    it("extension pattern takes priority over stripping", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])
      let request = test_request.create_request(Get, "/images/photo.jpg")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([])
      |> or_fail_with("Extension pattern should match (no params)")
    }),
    it("param route matches when extension not in pattern", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/images/*.{jpg,png}", test_handler, [])
        |> route(Get, "/images/:name", param_handler, [])
      let request = test_request.create_request(Get, "/images/document.gif")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("name", "document.gif")])
      |> or_fail_with("Param route should match non-pattern extension")
    }),
  ])
}

fn regression_tests() -> UnitTest {
  describe("regression tests", [
    it("does not match unregistered path", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
      let request = test_request.create_request(Get, "/products")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_none()
      |> or_fail_with("Should not match unregistered path")
    }),
    it("trailing slash is treated as same route", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/users", test_handler, [])
      let request = test_request.create_request(Get, "/users/")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> or_fail_with("Trailing slash should match same route")
    }),
    it("matches nested paths", fn() {
      // Arrange
      let test_router =
        router()
        |> route(Get, "/api/v1/users/:id/posts", test_handler, [])
      let request = test_request.create_request(Get, "/api/v1/users/123/posts")

      // Act
      let result = find_route(test_router, request)

      // Assert
      result
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "123")])
      |> or_fail_with("Should match deeply nested route")
    }),
  ])
}
