//// Tests for streaming functionality across dream modules.
////
//// These tests verify streaming behavior in request handling, middleware,
//// and route handlers.

import dream/context
import dream/dream
import dream/http/request.{
  type Method, type Request, Http, Http1, Post, Request, body_as_string,
}
import dream/http/response.{type Response, Response, Text}
import dream/router.{
  type EmptyServices, EmptyServices, Middleware, build_controller_chain,
}
import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/bit_array
import gleam/option
import gleam/yielder

// ============================================================================
// Helper Functions
// ============================================================================

fn create_streaming_request(stream: yielder.Yielder(BitArray)) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/test",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.Some(stream),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn create_buffered_request(body: String) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/test",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: body,
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn create_route_request(method: Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    stream: option.None,
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn test_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(200, Text("ok"), [], [], option.None)
}

fn echo_buffered_handler(
  request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(200, Text(request.body), [], [], option.None)
}

fn echo_stream_handler(
  request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  case request.stream {
    option.Some(stream) -> {
      let body =
        stream |> yielder.fold(<<>>, bit_array.append) |> bit_array.to_string
      case body {
        Ok(text) -> Response(200, Text(text), [], [], option.None)
        Error(_) -> Response(500, Text("Invalid UTF-8"), [], [], option.None)
      }
    }
    option.None -> Response(400, Text("Expected stream"), [], [], option.None)
  }
}

fn extract_body_text(response: Response) -> String {
  case response.body {
    Text(text) -> text
    _ -> ""
  }
}

fn create_test_router() -> router.Router(context.AppContext, EmptyServices) {
  router.router()
  |> router.route(Post, "/buffer", echo_buffered_handler, [])
  |> router.stream_route(Post, "/stream", echo_stream_handler, [])
}

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
      let stream = yielder.empty()
      let request = create_streaming_request(stream)

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("")
      |> or_fail_with("Empty stream should return empty string")
    }),
    it("returns error for invalid UTF-8", fn() {
      let stream = yielder.from_list([<<0xFF, 0xFF>>])
      let request = create_streaming_request(stream)

      body_as_string(request)
      |> should()
      |> be_error()
      |> or_fail_with("Invalid UTF-8 should return error")
    }),
    it("collects multiple chunks", fn() {
      let stream =
        yielder.from_list([
          bit_array.from_string("Chunk 1"),
          bit_array.from_string("Chunk 2"),
        ])
      let request = create_streaming_request(stream)

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("Chunk 1Chunk 2")
      |> or_fail_with("Should collect all chunks")
    }),
    it("handles many chunks", fn() {
      let chunks = [
        bit_array.from_string("Chunk 1 "),
        bit_array.from_string("Chunk 2 "),
        bit_array.from_string("Chunk 3 "),
        bit_array.from_string("Chunk 4 "),
        bit_array.from_string("Chunk 5"),
      ]
      let stream = yielder.from_list(chunks)
      let request = create_streaming_request(stream)

      body_as_string(request)
      |> should()
      |> be_ok()
      |> equal("Chunk 1 Chunk 2 Chunk 3 Chunk 4 Chunk 5")
      |> or_fail_with("Should handle many chunks")
    }),
    it("returns empty string for buffered empty body", fn() {
      let request = create_buffered_request("")

      body_as_string(request)
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
      let stream = yielder.from_list([bit_array.from_string("test")])
      let request = create_streaming_request(stream)
      let middleware = fn(request: Request, app_context, services, next) {
        next(request, app_context, services)
      }
      let chain = build_controller_chain([Middleware(middleware)], test_handler)
      let test_context = context.AppContext("id")

      chain(request, test_context, EmptyServices).status
      |> should()
      |> equal(200)
      |> or_fail_with("Middleware should preserve stream")
    }),
    it("can consume stream before controller", fn() {
      let stream = yielder.from_list([bit_array.from_string("secret")])
      let request = create_streaming_request(stream)

      let consuming_middleware = fn(
        request: Request,
        app_context,
        services,
        next,
      ) {
        case body_as_string(request) {
          Ok(body) -> {
            let new_request =
              Request(..request, body: body, stream: option.None)
            next(new_request, app_context, services)
          }
          Error(_) ->
            Response(500, Text("Stream read error"), [], [], option.None)
        }
      }

      let controller = fn(request: Request, _, _) -> Response {
        Response(200, Text(request.body), [], [], option.None)
      }

      let chain =
        build_controller_chain([Middleware(consuming_middleware)], controller)
      let test_context = context.AppContext("id")

      let response = chain(request, test_context, EmptyServices)

      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("Status should be 200")
    }),
    it("passes consumed body to controller", fn() {
      let stream = yielder.from_list([bit_array.from_string("consumed")])
      let request = create_streaming_request(stream)

      let consuming_middleware = fn(
        request: Request,
        app_context,
        services,
        next,
      ) {
        case body_as_string(request) {
          Ok(body) -> {
            let new_request =
              Request(..request, body: body, stream: option.None)
            next(new_request, app_context, services)
          }
          Error(_) ->
            Response(500, Text("Stream read error"), [], [], option.None)
        }
      }

      let controller = fn(request: Request, _, _) -> Response {
        Response(200, Text(request.body), [], [], option.None)
      }

      let chain =
        build_controller_chain([Middleware(consuming_middleware)], controller)
      let test_context = context.AppContext("id")

      extract_body_text(chain(request, test_context, EmptyServices))
      |> should()
      |> equal("consumed")
      |> or_fail_with("Controller should receive consumed body")
    }),
  ])
}

fn stream_error_tests() -> UnitTest {
  describe("stream error handling", [
    it("handles invalid UTF-8 gracefully", fn() {
      let invalid_chunk = <<0xFF, 0xFE, 0xFD>>
      let stream = yielder.from_list([invalid_chunk])
      let request = create_streaming_request(stream)

      body_as_string(request)
      |> should()
      |> be_error()
      |> or_fail_with("Should return error for invalid UTF-8")
    }),
    it("first consumption of stream works", fn() {
      let stream = yielder.from_list([bit_array.from_string("test")])
      let request = create_streaming_request(stream)

      body_as_string(request)
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
      let test_router = create_test_router()
      let request =
        Request(..create_route_request(Post, "/buffer"), body: "buffered data")

      let response =
        dream.route_request(
          test_router,
          request,
          context.AppContext("id"),
          EmptyServices,
        )

      extract_body_text(response)
      |> should()
      |> equal("buffered data")
      |> or_fail_with("Should receive buffered data")
    }),
    it("streaming route receives stream", fn() {
      let test_router = create_test_router()
      let stream = yielder.from_list([bit_array.from_string("streamed data")])
      let request =
        Request(
          ..create_route_request(Post, "/stream"),
          stream: option.Some(stream),
        )

      let response =
        dream.route_request(
          test_router,
          request,
          context.AppContext("id"),
          EmptyServices,
        )

      extract_body_text(response)
      |> should()
      |> equal("streamed data")
      |> or_fail_with("Should receive streamed data")
    }),
    it("streaming route handles empty stream", fn() {
      let test_router = create_test_router()
      let empty_stream = yielder.empty()
      let request =
        Request(
          ..create_route_request(Post, "/stream"),
          stream: option.Some(empty_stream),
        )

      let response =
        dream.route_request(
          test_router,
          request,
          context.AppContext("id"),
          EmptyServices,
        )

      extract_body_text(response)
      |> should()
      |> equal("")
      |> or_fail_with("Should handle empty stream")
    }),
    it("buffered route handles empty body", fn() {
      let test_router = create_test_router()
      let request = Request(..create_route_request(Post, "/buffer"), body: "")

      let response =
        dream.route_request(
          test_router,
          request,
          context.AppContext("id"),
          EmptyServices,
        )

      extract_body_text(response)
      |> should()
      |> equal("")
      |> or_fail_with("Should handle empty body")
    }),
    it("returns 404 for nonexistent route", fn() {
      let test_router = create_test_router()
      let request = create_route_request(Post, "/nonexistent")

      let response =
        dream.route_request(
          test_router,
          request,
          context.AppContext("id"),
          EmptyServices,
        )

      response.status
      |> should()
      |> equal(404)
      |> or_fail_with("Should return 404")
    }),
  ])
}
