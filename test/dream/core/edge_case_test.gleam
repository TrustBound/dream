import dream/context.{type AppContext}
import dream/http/request.{
  type Request, Http, Http1, Post, Request, body_as_string,
}
import dream/http/response.{type Response, Response, Text}
import dream/router.{
  type EmptyServices, EmptyServices, Middleware, build_controller_chain,
}
import gleam/bit_array
import gleam/option
import gleam/yielder
import gleeunit/should

// Mock handler
fn test_handler(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  Response(200, Text("ok"), [], [], option.None)
}

// ===== Edge Cases for Streaming =====

pub fn streaming_body_as_string_with_empty_stream_returns_empty_string_test() {
  // Arrange
  let stream = yielder.empty()
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.equal(Ok(""))
}

pub fn streaming_body_as_string_with_invalid_utf8_returns_error_test() {
  // Arrange
  // Invalid UTF-8 sequence
  let stream = yielder.from_list([<<0xFF, 0xFF>>])
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.be_error
}

pub fn streaming_body_as_string_collects_multiple_chunks_test() {
  // Arrange
  let stream =
    yielder.from_list([
      bit_array.from_string("Chunk 1"),
      bit_array.from_string("Chunk 2"),
    ])
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.equal(Ok("Chunk 1Chunk 2"))
}

// ===== Middleware Edge Cases =====

pub fn middleware_with_streaming_request_preserves_stream_test() {
  // Arrange
  let stream = yielder.from_list([bit_array.from_string("test")])
  let request = create_streaming_request(stream)
  let middleware = fn(request: Request, context, services, next) {
    next(request, context, services)
  }
  let chain = build_controller_chain([Middleware(middleware)], test_handler)
  let test_context = context.AppContext("id")
  let test_services = EmptyServices

  // Act
  let response = chain(request, test_context, test_services)

  // Assert
  response.status |> should.equal(200)
}

pub fn middleware_can_consume_stream_before_controller_test() {
  // Arrange
  let stream = yielder.from_list([bit_array.from_string("secret")])
  let request = create_streaming_request(stream)

  let consuming_middleware = fn(request: Request, context, services, next) {
    case body_as_string(request) {
      Ok(body) -> {
        let new_request = Request(..request, body: body, stream: option.None)
        next(new_request, context, services)
      }
      Error(_) -> {
        Response(500, Text("Stream read error"), [], [], option.None)
      }
    }
  }

  let controller = fn(request: Request, _, _) -> Response {
    Response(200, Text(request.body), [], [], option.None)
  }

  let chain =
    build_controller_chain([Middleware(consuming_middleware)], controller)
  let test_context = context.AppContext("id")
  let test_services = EmptyServices

  // Act
  let response = chain(request, test_context, test_services)

  // Assert
  response.status |> should.equal(200)
  case response.body {
    Text(body_text) -> {
      body_text |> should.equal("secret")
    }
    _ -> should.fail()
  }
}

// Helpers

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
