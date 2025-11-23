import dream/context
import dream/dream
import dream/http/request.{type Method, type Request, Http, Http1, Post, Request}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type EmptyServices, EmptyServices}
import gleam/bit_array
import gleam/option
import gleam/yielder
import gleeunit/should

// Since we can't easily mock the full Mist server stack in unit tests,
// we simulate the handler logic here to verify the integration points.

// Test router helpers
fn create_test_router() -> router.Router(context.AppContext, EmptyServices) {
  router.router()
  |> router.route(
    method: Post,
    path: "/buffer",
    controller: echo_buffered_handler,
    middleware: [],
  )
  |> router.stream_route(
    method: Post,
    path: "/stream",
    controller: echo_stream_handler,
    middleware: [],
  )
}

// Test handlers - these should NOT contain assertions
fn echo_buffered_handler(request: Request, _, _) -> Response {
  Response(200, Text(request.body), [], [], option.None)
}

fn echo_stream_handler(request: Request, _, _) -> Response {
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

// Simulation helpers
fn simulate_handler(
  test_router: router.Router(context.AppContext, EmptyServices),
  request: Request,
  is_streaming_route: Bool,
) -> Response {
  // Simulate what handler.gleam does
  let final_request = case is_streaming_route {
    True -> {
      // Simulate streaming wrapping
      let stream = yielder.from_list([bit_array.from_string("streamed data")])
      Request(..request, body: "", stream: option.Some(stream))
    }
    False -> {
      // Simulate buffered reading
      Request(..request, body: "buffered data", stream: option.None)
    }
  }

  dream.route_request(
    test_router,
    final_request,
    context.AppContext("id"),
    EmptyServices,
  )
}

fn create_request(method: Method, path: String) -> Request {
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

// Tests

pub fn buffered_route_receives_full_body_test() {
  // Arrange
  let test_router = create_test_router()
  let request = create_request(Post, "/buffer")

  // Act
  let response = simulate_handler(test_router, request, False)

  // Assert
  response.status |> should.equal(200)
  case response.body {
    Text(text) -> text |> should.equal("buffered data")
    _ -> should.fail()
  }
}

pub fn streaming_route_receives_stream_test() {
  // Arrange
  let test_router = create_test_router()
  let request = create_request(Post, "/stream")

  // Act
  let response = simulate_handler(test_router, request, True)

  // Assert
  response.status |> should.equal(200)
  case response.body {
    Text(text) -> text |> should.equal("streamed data")
    _ -> should.fail()
  }
}

pub fn streaming_route_with_empty_body_handles_correctly_test() {
  // Arrange
  let test_router = create_test_router()
  let request = create_request(Post, "/stream")

  // Act - simulate empty stream
  let empty_stream = yielder.empty()
  let final_request =
    Request(..request, body: "", stream: option.Some(empty_stream))
  let response =
    dream.route_request(
      test_router,
      final_request,
      context.AppContext("id"),
      EmptyServices,
    )

  // Assert
  response.status |> should.equal(200)
  case response.body {
    Text(text) -> text |> should.equal("")
    _ -> should.fail()
  }
}

pub fn buffered_route_with_empty_body_handles_correctly_test() {
  // Arrange
  let test_router = create_test_router()
  let request = create_request(Post, "/buffer")

  // Act - simulate empty buffered body
  let final_request = Request(..request, body: "", stream: option.None)
  let response =
    dream.route_request(
      test_router,
      final_request,
      context.AppContext("id"),
      EmptyServices,
    )

  // Assert
  response.status |> should.equal(200)
  case response.body {
    Text(text) -> text |> should.equal("")
    _ -> should.fail()
  }
}

pub fn route_not_found_returns_404_without_reading_body_test() {
  // Arrange
  let test_router = create_test_router()
  let request = create_request(Post, "/nonexistent")

  // Act
  let response =
    dream.route_request(
      test_router,
      request,
      context.AppContext("id"),
      EmptyServices,
    )

  // Assert
  response.status |> should.equal(404)
  case response.body {
    Text(text) -> text |> should.equal("Route not found")
    _ -> should.fail()
  }
}
