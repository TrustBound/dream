//// Tests for streaming functionality across dream modules.
////
//// These tests verify streaming behavior in request handling, middleware,
//// and route handlers.

import dream/context
import dream/dream
import dream/http/request.{type Request, Post, Request, body_as_string}
import dream/http/response.{type Response, Response, Text}
import dream/router.{
  type EmptyServices, EmptyServices, Middleware, build_controller_chain, route,
  stream_route,
}
import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{
  echo_buffered_handler, echo_stream_handler, test_handler,
}
import fixtures/request as test_request
import gleam/bit_array
import gleam/option
import gleam/yielder
import matchers/extract_body_text.{extract_body_text}

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("streaming", [
    body_as_string_tests(),
    middleware_streaming_tests(),
    stream_error_tests(),
    route_streaming_tests(),
  ])
}

fn body_as_string_tests() -> UnitTest {
  describe("body_as_string", [
    it("returns empty string for empty stream", fn() {
      // Arrange
      let stream = yielder.empty()
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Empty stream should return empty string")
    }),
    it("returns error for invalid UTF-8", fn() {
      // Arrange
      let stream = yielder.from_list([<<0xFF, 0xFF>>])
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_error()
      |> or_fail_with("Invalid UTF-8 should return error")
    }),
    it("collects multiple chunks", fn() {
      // Arrange
      let stream =
        yielder.from_list([
          bit_array.from_string("Chunk 1"),
          bit_array.from_string("Chunk 2"),
        ])
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("Chunk 1Chunk 2")
      |> or_fail_with("Should collect all chunks")
    }),
    it("handles many chunks", fn() {
      // Arrange
      let chunks = [
        bit_array.from_string("Chunk 1 "),
        bit_array.from_string("Chunk 2 "),
        bit_array.from_string("Chunk 3 "),
        bit_array.from_string("Chunk 4 "),
        bit_array.from_string("Chunk 5"),
      ]
      let stream = yielder.from_list(chunks)
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("Chunk 1 Chunk 2 Chunk 3 Chunk 4 Chunk 5")
      |> or_fail_with("Should handle many chunks")
    }),
    it("returns empty string for buffered empty body", fn() {
      // Arrange
      let request = test_request.create_request_with_body(Post, "/test", "")

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Empty buffered body should return empty string")
    }),
  ])
}

fn middleware_streaming_tests() -> UnitTest {
  describe("middleware with streaming", [
    it("preserves stream through pass-through middleware", fn() {
      // Arrange
      let stream = yielder.from_list([bit_array.from_string("test")])
      let request = test_request.create_streaming_request(Post, "/test", stream)
      let middleware = fn(inner_request: Request, app_context, services, next) {
        next(inner_request, app_context, services)
      }
      let chain = build_controller_chain([Middleware(middleware)], test_handler)
      let test_context = context.AppContext("id")

      // Act
      let response = chain(request, test_context, EmptyServices)

      // Assert
      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("Middleware should preserve stream")
    }),
    it("can consume stream before controller", fn() {
      // Arrange
      let stream = yielder.from_list([bit_array.from_string("secret")])
      let request = test_request.create_streaming_request(Post, "/test", stream)
      let consuming_middleware = fn(
        inner_request: Request,
        app_context,
        services,
        next,
      ) {
        case body_as_string(inner_request) {
          Ok(body) -> {
            let new_request =
              Request(..inner_request, body: body, stream: option.None)
            next(new_request, app_context, services)
          }
          Error(_stream_error) ->
            Response(500, Text("Stream read error"), [], [], option.None)
        }
      }
      let controller = fn(inner_request: Request, _ctx, _svc) -> Response {
        Response(200, Text(inner_request.body), [], [], option.None)
      }
      let chain =
        build_controller_chain([Middleware(consuming_middleware)], controller)
      let test_context = context.AppContext("id")

      // Act
      let response = chain(request, test_context, EmptyServices)

      // Assert
      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("Status should be 200")
    }),
    it("passes consumed body to controller", fn() {
      // Arrange
      let stream = yielder.from_list([bit_array.from_string("consumed")])
      let request = test_request.create_streaming_request(Post, "/test", stream)
      let consuming_middleware = fn(
        inner_request: Request,
        app_context,
        services,
        next,
      ) {
        case body_as_string(inner_request) {
          Ok(body) -> {
            let new_request =
              Request(..inner_request, body: body, stream: option.None)
            next(new_request, app_context, services)
          }
          Error(_stream_error) ->
            Response(500, Text("Stream read error"), [], [], option.None)
        }
      }
      let controller = fn(inner_request: Request, _ctx, _svc) -> Response {
        Response(200, Text(inner_request.body), [], [], option.None)
      }
      let chain =
        build_controller_chain([Middleware(consuming_middleware)], controller)
      let test_context = context.AppContext("id")

      // Act
      let response = chain(request, test_context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("consumed")
      |> or_fail_with("Controller should receive consumed body")
    }),
  ])
}

fn stream_error_tests() -> UnitTest {
  describe("stream error handling", [
    it("handles invalid UTF-8 gracefully", fn() {
      // Arrange
      let invalid_chunk = <<0xFF, 0xFE, 0xFD>>
      let stream = yielder.from_list([invalid_chunk])
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_error()
      |> or_fail_with("Should return error for invalid UTF-8")
    }),
    it("first consumption of stream works", fn() {
      // Arrange
      let stream = yielder.from_list([bit_array.from_string("test")])
      let request = test_request.create_streaming_request(Post, "/test", stream)

      // Act
      let result = body_as_string(request)

      // Assert
      result
      |> should()
      |> be_ok()
      |> equal("test")
      |> or_fail_with("First consumption should work")
    }),
  ])
}

fn route_streaming_tests() -> UnitTest {
  describe("route streaming", [
    it("buffered route receives full body", fn() {
      // Arrange
      let test_router = create_test_router()
      let request =
        test_request.create_request_with_body(Post, "/buffer", "buffered data")
      let app_context = context.AppContext("id")

      // Act
      let response =
        dream.route_request(test_router, request, app_context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("buffered data")
      |> or_fail_with("Should receive buffered data")
    }),
    it("streaming route receives stream", fn() {
      // Arrange
      let test_router = create_test_router()
      let stream = yielder.from_list([bit_array.from_string("streamed data")])
      let request =
        test_request.create_streaming_request(Post, "/stream", stream)
      let app_context = context.AppContext("id")

      // Act
      let response =
        dream.route_request(test_router, request, app_context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("streamed data")
      |> or_fail_with("Should receive streamed data")
    }),
    it("streaming route handles empty stream", fn() {
      // Arrange
      let test_router = create_test_router()
      let empty_stream = yielder.empty()
      let request =
        test_request.create_streaming_request(Post, "/stream", empty_stream)
      let app_context = context.AppContext("id")

      // Act
      let response =
        dream.route_request(test_router, request, app_context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("")
      |> or_fail_with("Should handle empty stream")
    }),
    it("buffered route handles empty body", fn() {
      // Arrange
      let test_router = create_test_router()
      let request = test_request.create_request_with_body(Post, "/buffer", "")
      let app_context = context.AppContext("id")

      // Act
      let response =
        dream.route_request(test_router, request, app_context, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("")
      |> or_fail_with("Should handle empty body")
    }),
    it("returns 404 for nonexistent route", fn() {
      // Arrange
      let test_router = create_test_router()
      let request = test_request.create_request(Post, "/nonexistent")
      let app_context = context.AppContext("id")

      // Act
      let response =
        dream.route_request(test_router, request, app_context, EmptyServices)

      // Assert
      response.status
      |> should()
      |> equal(404)
      |> or_fail_with("Should return 404")
    }),
  ])
}

// ============================================================================
// Test Router Factory
// ============================================================================

fn create_test_router() -> router.Router(context.AppContext, EmptyServices) {
  router.router()
  |> route(Post, "/buffer", echo_buffered_handler, [])
  |> stream_route(Post, "/stream", echo_stream_handler, [])
}
