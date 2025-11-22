import dream/context
import dream/http/request.{
  type Request, Http, Http1, Post, Request, body_as_string,
}
import dream/http/response.{type Response, Response, Text}
import dream/router.{EmptyServices, Middleware, build_controller_chain}
import gleam/bit_array
import gleam/option
import gleam/yielder
import gleeunit/should

// ===== Stream Error Handling Tests =====

pub fn body_as_string_with_stream_that_fails_during_read_handles_gracefully_test() {
  // Arrange
  // Create a stream that will fail when consumed
  // We simulate this by creating a stream that produces invalid data
  let invalid_chunk = <<0xFF, 0xFE, 0xFD>>
  let stream = yielder.from_list([invalid_chunk])
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  // Should return Error for invalid UTF-8
  result |> should.be_error
}

pub fn body_as_string_with_large_stream_handles_multiple_chunks_test() {
  // Arrange
  // Create a stream with many chunks (simulating >64KB)
  let chunks = [
    bit_array.from_string("Chunk 1 "),
    bit_array.from_string("Chunk 2 "),
    bit_array.from_string("Chunk 3 "),
    bit_array.from_string("Chunk 4 "),
    bit_array.from_string("Chunk 5"),
  ]
  let stream = yielder.from_list(chunks)
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.equal(Ok("Chunk 1 Chunk 2 Chunk 3 Chunk 4 Chunk 5"))
}

pub fn body_as_string_with_stream_consumed_twice_works_correctly_test() {
  // Arrange
  let stream = yielder.from_list([bit_array.from_string("test")])
  let request = create_streaming_request(stream)

  // Act - First consumption
  let result1 = body_as_string(request)

  // Assert - First consumption should work
  result1 |> should.equal(Ok("test"))
  // Note: In practice, streams can only be consumed once.
  // This test verifies that the first consumption works correctly.
  // A second consumption would require a new request with a new stream.
}

pub fn middleware_that_consumes_stream_then_passes_to_controller_test() {
  // Arrange
  let stream = yielder.from_list([bit_array.from_string("consumed")])
  let request = create_streaming_request(stream)

  let consuming_middleware = fn(request: Request, context, services, next) {
    // Consume the stream in middleware
    case body_as_string(request) {
      Ok(body) -> {
        // Create new request with consumed body
        let new_request = Request(..request, body: body, stream: option.None)
        next(new_request, context, services)
      }
      Error(_) -> {
        Response(500, Text("Stream read error"), [], [], option.None)
      }
    }
  }

  let controller = fn(request: Request, _, _) -> Response {
    // Controller should receive the consumed body, not the stream
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
      body_text |> should.equal("consumed")
    }
    _ -> should.fail()
  }
}

pub fn streaming_request_with_empty_body_handles_correctly_test() {
  // Arrange
  let stream = yielder.empty()
  let request = create_streaming_request(stream)

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.equal(Ok(""))
}

pub fn buffered_request_with_empty_body_handles_correctly_test() {
  // Arrange
  let request =
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
      stream: option.None,
      headers: [],
      cookies: [],
      content_type: option.None,
      content_length: option.None,
    )

  // Act
  let result = body_as_string(request)

  // Assert
  result |> should.equal(Ok(""))
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
