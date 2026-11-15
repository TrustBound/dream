//// Tests for the snippets in docs/guides/sse.md, docs/guides/websockets.md
//// and docs/guides/rest-api.md.
////
//// Each snippet in test/snippets/ is shown, character for character, in one
//// of those guides. Tests that need a real server ask the operating system
//// for a free port, because other test runs on this machine use ports too.

import dream/context.{type AppContext, type EmptyContext, new_context}
import dream/dream
import dream/http/error.{BadRequest, NotFound}
import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Post, Request}
import dream/http/response.{type Response, Response, Text, json_response}
import dream/http/validation.{validate_json}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import dream/servers/mist/sse
import dream/services/broadcaster
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/rest_api_guide_cors
import snippets/rest_api_guide_create
import snippets/rest_api_guide_cursor_pagination.{Page, Product}
import snippets/rest_api_guide_domain_errors
import snippets/rest_api_guide_filtering
import snippets/rest_api_guide_header_versioning
import snippets/rest_api_guide_pagination
import snippets/rest_api_guide_url_versioning
import snippets/rest_api_guide_validation
import snippets/sse_guide_broadcast.{AppEvent}
import snippets/sse_guide_events
import snippets/sse_guide_middleware
import snippets/sse_guide_router
import snippets/websockets_guide_auth
import snippets/websockets_guide_chat.{ChatMessage}
import snippets/websockets_guide_router

pub fn tests() -> UnitTest {
  describe("guide snippets", [
    sse_guide_tests(),
    websockets_guide_tests(),
    rest_api_guide_tests(),
  ])
}

// ============================================================================
// SSE guide
// ============================================================================

fn sse_guide_tests() -> UnitTest {
  describe("sse guide", [
    it("the ticker sends tick events with a rising count", fn() {
      // Arrange
      let app_router = sse_guide_router.create_router()

      // Act
      let body =
        read_event_stream(app_router, Nil, "/events", 2)
        |> result.map(response_body)

      // Assert
      body
      |> should()
      |> equal(Ok(
        "id: 0\nevent: tick\ndata: {\"count\": 0}\n\nid: 1\nevent: tick\ndata: {\"count\": 1}\n\n",
      ))
      |> or_fail_with("the ticker should send count 0 and then count 1")
    }),
    it("build_minimal_event sends only data", fn() {
      // Arrange
      let event = sse_guide_events.build_minimal_event()

      // Act
      let body =
        read_event_stream(event_router(), event, "/event", 1)
        |> result.map(response_body)

      // Assert
      body
      |> should()
      |> equal(Ok("data: hello world\n\n"))
      |> or_fail_with("the minimal event should hold only data")
    }),
    it("build_full_event sends name, id, retry and data", fn() {
      // Arrange
      let event = sse_guide_events.build_full_event()

      // Act
      let body =
        read_event_stream(event_router(), event, "/event", 1)
        |> result.map(response_body)

      // Assert
      body
      |> should()
      |> equal(Ok("retry: 5000\nid: 42\nevent: tick\ndata: {\"count\": 42}\n\n"))
      |> or_fail_with("the full event should hold every field")
    }),
    it("the middleware adds the CORS header to the SSE response", fn() {
      // Arrange
      let app_router = sse_guide_middleware.create_router()

      // Act
      let header =
        read_event_stream(app_router, Nil, "/events", 1)
        |> result.map(find_header(_, "access-control-allow-origin"))

      // Assert
      header
      |> should()
      |> equal(Ok(Ok("*")))
      |> or_fail_with(
        "the SSE response should hold Access-Control-Allow-Origin: *",
      )
    }),
    it("the broadcast controller sends each published event", fn() {
      // Arrange
      let assert Ok(event_bus) = broadcaster.start_broadcaster()

      // Act
      let body =
        read_broadcast_stream(event_bus, "hello") |> result.map(response_body)

      // Assert
      body
      |> should()
      |> equal(Ok("id: 0\ndata: hello\n\n"))
      |> or_fail_with("the client should get the published hello event")
    }),
  ])
}

// ============================================================================
// WebSockets guide
// ============================================================================

fn websockets_guide_tests() -> UnitTest {
  describe("websockets guide", [
    it("initialize starts the chat bus", fn() {
      // Arrange
      let started = websockets_guide_chat.initialize()

      // Act
      let is_started = result.is_ok(started)

      // Assert
      is_started
      |> should()
      |> equal(True)
      |> or_fail_with("initialize should return Ok(Services)")
    }),
    it("the chat sends a message back to its sender with the user name", fn() {
      // Arrange
      let assert Ok(services) = websockets_guide_chat.initialize()

      // Act
      let reply = chat_round_trip(services, "/chat?user=ada", "hello")

      // Assert
      reply
      |> should()
      |> equal(Ok("ada: hello"))
      |> or_fail_with("the chat should reply 'ada: hello'")
    }),
    it("the chat uses Anonymous when the user query parameter is missing", fn() {
      // Arrange
      let assert Ok(services) = websockets_guide_chat.initialize()

      // Act
      let reply = chat_round_trip(services, "/chat", "hello")

      // Assert
      reply
      |> should()
      |> equal(Ok("Anonymous: hello"))
      |> or_fail_with("the chat should reply 'Anonymous: hello'")
    }),
    it("the chat publishes the message and then a leave message", fn() {
      // Arrange
      let assert Ok(services) = websockets_guide_chat.initialize()
      let selector =
        broadcaster.subscribe(services.chat_bus)
        |> broadcaster.channel_to_selector

      // Act
      let messages = chat_and_receive(services, selector, 2)

      // Assert
      messages
      |> should()
      |> equal(
        Ok([
          ChatMessage(sender: "ada", content: "hello"),
          ChatMessage(sender: "ada", content: "ada left the chat"),
        ]),
      )
      |> or_fail_with("the bus should get 'hello', then the leave message")
    }),
    it("publish_chat_message sends the message to subscribers", fn() {
      // Arrange
      let assert Ok(services) = websockets_guide_chat.initialize()
      let selector =
        broadcaster.subscribe(services.chat_bus)
        |> broadcaster.channel_to_selector

      // Act
      websockets_guide_chat.publish_chat_message(services, "ada", "hi")
      let messages = receive_messages(selector, 1)

      // Assert
      messages
      |> should()
      |> equal(Ok([ChatMessage(sender: "ada", content: "hi")]))
      |> or_fail_with("the subscriber should get ChatMessage(ada, hi)")
    }),
    it("handle_upgrade accepts a valid auth token", fn() {
      // Arrange
      let headers = [#("Authorization", "Bearer token-for-ada")]

      // Act
      let reply = auth_round_trip(headers, "hello")

      // Assert
      reply
      |> should()
      |> equal(Ok("ada: hello"))
      |> or_fail_with("an upgrade with a valid token should reply 'ada: hello'")
    }),
    it("handle_upgrade answers 401 to an unknown auth token", fn() {
      // Arrange
      let headers = [#("Authorization", "Bearer unknown-token")]

      // Act
      let reply = auth_round_trip(headers, "hello")

      // Assert
      reply
      |> should()
      |> equal(Error("HTTP/1.1 401 Unauthorized"))
      |> or_fail_with("an upgrade with an unknown token should get 401")
    }),
    it("handle_upgrade answers 401 when the auth header is missing", fn() {
      // Arrange
      let headers = []

      // Act
      let reply = auth_round_trip(headers, "hello")

      // Assert
      reply
      |> should()
      |> equal(Error("HTTP/1.1 401 Unauthorized"))
      |> or_fail_with("an upgrade with no token should get 401")
    }),
  ])
}

@external(erlang, "websockets_guide_test_ffi", "send_text_and_receive")
fn send_text_and_receive(
  port: Int,
  path: String,
  headers: List(#(String, String)),
  text: String,
  timeout: Int,
) -> Result(String, String)

/// Starts the guide's chat router, sends one text frame over a WebSocket
/// and returns the first text frame the server sends back.
fn chat_round_trip(
  services: websockets_guide_chat.Services,
  path: String,
  text: String,
) -> Result(String, String) {
  let port = free_port()
  case start_server(websockets_guide_router.create_router(), services, port) {
    Ok(handle) -> {
      let reply = send_text_and_receive(port, path, [], text, 2000)
      server.stop(handle)
      reply
    }
    Error(message) -> Error(message)
  }
}

/// Starts the guide's chat router, sends "hello" as ada, closes the socket,
/// and then, while the server still runs, receives `count` messages from
/// `selector`.
fn chat_and_receive(
  services: websockets_guide_chat.Services,
  selector: process.Selector(message),
  count: Int,
) -> Result(List(message), Nil) {
  let port = free_port()
  case start_server(websockets_guide_router.create_router(), services, port) {
    Ok(handle) -> {
      let _reply =
        send_text_and_receive(port, "/chat?user=ada", [], "hello", 2000)
      let messages = receive_messages(selector, count)
      server.stop(handle)
      messages
    }
    Error(_message) -> Error(Nil)
  }
}

/// Starts the guide's auth controller with one user, ada, and sends one
/// text frame over a WebSocket opened with `headers`.
fn auth_round_trip(
  headers: List(#(String, String)),
  text: String,
) -> Result(String, String) {
  let assert Ok(chat_bus) = broadcaster.start_broadcaster()
  let services =
    websockets_guide_auth.Services(chat_bus: chat_bus, users: [
      websockets_guide_auth.User(name: "ada", token: "token-for-ada"),
    ])
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/chat",
      controller: websockets_guide_auth.handle_upgrade,
      middleware: [],
    )
  let port = free_port()
  case start_server(app_router, services, port) {
    Ok(handle) -> {
      let reply = send_text_and_receive(port, "/chat", headers, text, 2000)
      server.stop(handle)
      reply
    }
    Error(message) -> Error(message)
  }
}

/// Receives `count` messages from `selector`, waiting at most 2 seconds
/// for each one.
fn receive_messages(
  selector: process.Selector(message),
  count: Int,
) -> Result(List(message), Nil) {
  case count {
    0 -> Ok([])
    _ -> {
      use message <- result.try(process.selector_receive(selector, 2000))
      use rest <- result.map(receive_messages(selector, count - 1))
      [message, ..rest]
    }
  }
}

// ============================================================================
// REST API guide
// ============================================================================

fn rest_api_guide_tests() -> UnitTest {
  describe("rest api guide", [
    rest_api_pagination_tests(),
    rest_api_cursor_pagination_tests(),
    rest_api_validation_tests(),
    rest_api_errors_tests(),
    rest_api_versioning_tests(),
    rest_api_filtering_tests(),
    rest_api_cors_tests(),
  ])
}

fn rest_api_products() -> List(rest_api_guide_pagination.Product) {
  [
    rest_api_guide_pagination.Product(id: 1, name: "Lamp"),
    rest_api_guide_pagination.Product(id: 2, name: "Desk"),
    rest_api_guide_pagination.Product(id: 3, name: "Chair"),
  ]
}

fn rest_api_pagination_tests() -> UnitTest {
  describe("pagination", [
    it("index returns the page that offset and limit select", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(
          Get,
          "/products",
          "offset=1&limit=1",
        )
      let services = rest_api_guide_pagination.Services(rest_api_products())

      // Act
      let response =
        rest_api_guide_pagination.index(request, new_context("test"), services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal(
        "{\"data\":[{\"id\":2,\"name\":\"Desk\"}],\"offset\":1,\"limit\":1}",
      )
      |> or_fail_with("index should return product 2 only")
    }),
    it("index uses offset 0 and limit 20 when the query is empty", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products")
      let services = rest_api_guide_pagination.Services(rest_api_products())

      // Act
      let response =
        rest_api_guide_pagination.index(request, new_context("test"), services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal(
        "{\"data\":[{\"id\":1,\"name\":\"Lamp\"},{\"id\":2,\"name\":\"Desk\"},{\"id\":3,\"name\":\"Chair\"}],\"offset\":0,\"limit\":20}",
      )
      |> or_fail_with("index should return every product")
    }),
  ])
}

fn cursor_products() -> List(rest_api_guide_cursor_pagination.Product) {
  [
    Product(id: 1, name: "Lamp"),
    Product(id: 2, name: "Desk"),
    Product(id: 3, name: "Chair"),
    Product(id: 4, name: "Shelf"),
    Product(id: 5, name: "Rug"),
  ]
}

fn rest_api_cursor_pagination_tests() -> UnitTest {
  describe("cursor pagination", [
    it("list_after with no cursor returns the first page and its cursor", fn() {
      // Arrange
      let products = cursor_products()

      // Act
      let result =
        rest_api_guide_cursor_pagination.list_after(products, None, 2)

      // Assert
      result
      |> should()
      |> equal(
        Ok(Page(
          items: [Product(id: 1, name: "Lamp"), Product(id: 2, name: "Desk")],
          next_cursor: Some("Mg"),
        )),
      )
      |> or_fail_with("first page should hold ids 1 and 2, cursor Mg")
    }),
    it("list_after returns the middle page after the cursor", fn() {
      // Arrange
      let products = cursor_products()

      // Act
      let result =
        rest_api_guide_cursor_pagination.list_after(products, Some("Mg"), 2)

      // Assert
      result
      |> should()
      |> equal(
        Ok(Page(
          items: [Product(id: 3, name: "Chair"), Product(id: 4, name: "Shelf")],
          next_cursor: Some("NA"),
        )),
      )
      |> or_fail_with("middle page should hold ids 3 and 4, cursor NA")
    }),
    it("list_after returns the last page with no next cursor", fn() {
      // Arrange
      let products = cursor_products()

      // Act
      let result =
        rest_api_guide_cursor_pagination.list_after(products, Some("NA"), 2)

      // Assert
      result
      |> should()
      |> equal(
        Ok(Page(items: [Product(id: 5, name: "Rug")], next_cursor: None)),
      )
      |> or_fail_with("last page should hold id 5 and no cursor")
    }),
    it(
      "list_after gives no next cursor when the page ends at the last row",
      fn() {
        // Arrange
        let products = cursor_products()

        // Act
        let result =
          rest_api_guide_cursor_pagination.list_after(products, Some("Mg"), 3)

        // Assert
        result
        |> should()
        |> equal(
          Ok(Page(
            items: [
              Product(id: 3, name: "Chair"),
              Product(id: 4, name: "Shelf"),
              Product(id: 5, name: "Rug"),
            ],
            next_cursor: None,
          )),
        )
        |> or_fail_with("a full last page should have no cursor")
      },
    ),
    it("list_after rejects a cursor that is not an encoded id", fn() {
      // Arrange
      let products = cursor_products()

      // Act
      let result =
        rest_api_guide_cursor_pagination.list_after(products, Some("YWJj"), 2)

      // Assert
      result
      |> should()
      |> equal(Error(BadRequest("Invalid cursor")))
      |> or_fail_with("cursor YWJj decodes to abc and should be rejected")
    }),
  ])
}

fn rest_api_validation_tests() -> UnitTest {
  describe("validation", [
    it("decoder accepts valid product data", fn() {
      // Arrange
      let body =
        "{\"name\":\"Lamp\",\"price\":30,\"description\":\"A desk lamp\"}"

      // Act
      let result = validate_json(body, rest_api_guide_validation.decoder())

      // Assert
      result
      |> should()
      |> equal(
        Ok(rest_api_guide_validation.ProductData("Lamp", 30, "A desk lamp")),
      )
      |> or_fail_with("decoder should return the product data")
    }),
    it("validate_product_data rejects an empty name", fn() {
      // Arrange
      let data = rest_api_guide_validation.ProductData("", 30, "A desk lamp")

      // Act
      let result = rest_api_guide_validation.validate_product_data(data)

      // Assert
      result
      |> should()
      |> equal(Error("Name cannot be empty"))
      |> or_fail_with(
        "validate_product_data should return 'Name cannot be empty'",
      )
    }),
    it("validate_product_data rejects a negative price", fn() {
      // Arrange
      let data =
        rest_api_guide_validation.ProductData("Lamp", -1, "A desk lamp")

      // Act
      let result = rest_api_guide_validation.validate_product_data(data)

      // Assert
      result
      |> should()
      |> equal(Error("Price cannot be negative"))
      |> or_fail_with(
        "validate_product_data should return 'Price cannot be negative'",
      )
    }),
  ])
}

fn rest_api_errors_tests() -> UnitTest {
  describe("errors", [
    it("find_product returns the product with the id", fn() {
      // Arrange
      let products = [
        rest_api_guide_domain_errors.Product(id: 1, name: "Lamp"),
        rest_api_guide_domain_errors.Product(id: 2, name: "Desk"),
      ]

      // Act
      let result = rest_api_guide_domain_errors.find_product(products, 2)

      // Assert
      result
      |> should()
      |> equal(Ok(rest_api_guide_domain_errors.Product(id: 2, name: "Desk")))
      |> or_fail_with("find_product should return product 2")
    }),
    it("find_product returns NotFound for an unknown id", fn() {
      // Arrange
      let products = [rest_api_guide_domain_errors.Product(id: 1, name: "Lamp")]

      // Act
      let result = rest_api_guide_domain_errors.find_product(products, 9)

      // Assert
      result
      |> should()
      |> equal(Error(NotFound("Product not found")))
      |> or_fail_with("find_product should return NotFound")
    }),
    it("create returns 201 with the new product as JSON", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Post,
          "/products",
          "{\"name\":\"Lamp\",\"price\":30,\"description\":\"A desk lamp\"}",
        )
      let services = rest_api_guide_create.Services(next_product_id: 7)

      // Act
      let response =
        rest_api_guide_create.create(request, new_context("test"), services)

      // Assert
      #(response.status, response.body)
      |> should()
      |> equal(#(
        201,
        Text(
          "{\"id\":7,\"name\":\"Lamp\",\"price\":30,\"description\":\"A desk lamp\"}",
        ),
      ))
      |> or_fail_with("create should return 201 and the product")
    }),
    it("create returns 400 with the parse message for bad JSON", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Post, "/products", "{")
      let services = rest_api_guide_create.Services(next_product_id: 7)

      // Act
      let response =
        rest_api_guide_create.create(request, new_context("test"), services)

      // Assert
      #(response.status, response.body)
      |> should()
      |> equal(#(400, Text("{\"error\":\"Unexpected end of JSON input\"}")))
      |> or_fail_with("create should return 400 and the parse message")
    }),
    it("create returns 422 with the validation message", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(
          Post,
          "/products",
          "{\"name\":\"Lamp\",\"price\":-1,\"description\":\"A desk lamp\"}",
        )
      let services = rest_api_guide_create.Services(next_product_id: 7)

      // Act
      let response =
        rest_api_guide_create.create(request, new_context("test"), services)

      // Assert
      #(response.status, response.body)
      |> should()
      |> equal(#(422, Text("{\"error\":\"Price cannot be negative\"}")))
      |> or_fail_with("create should return 422 and the message")
    }),
  ])
}

fn rest_api_versioning_tests() -> UnitTest {
  describe("versioning", [
    it("the router sends /v2/products to the version 2 controller", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/v2/products")

      // Act
      let response =
        dream.route_request(
          rest_api_guide_url_versioning.create_router(),
          request,
          new_context("test"),
          rest_api_guide_url_versioning.Services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"version\": \"2\"}")
      |> or_fail_with("GET /v2/products should return version 2")
    }),
    it("the router sends /v1/products to the version 1 controller", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/v1/products")

      // Act
      let response =
        dream.route_request(
          rest_api_guide_url_versioning.create_router(),
          request,
          new_context("test"),
          rest_api_guide_url_versioning.Services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"version\": \"1\"}")
      |> or_fail_with("GET /v1/products should return version 1")
    }),
    it("index uses version 2 when API-Version is 2", fn() {
      // Arrange
      let request = request_with_api_version([Header("API-Version", "2")])

      // Act
      let response =
        rest_api_guide_header_versioning.index(
          request,
          new_context("test"),
          rest_api_guide_header_versioning.Services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"version\": \"2\"}")
      |> or_fail_with("API-Version 2 should return version 2")
    }),
    it("index uses version 1 when API-Version is missing", fn() {
      // Arrange
      let request = request_with_api_version([])

      // Act
      let response =
        rest_api_guide_header_versioning.index(
          request,
          new_context("test"),
          rest_api_guide_header_versioning.Services,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"version\": \"1\"}")
      |> or_fail_with("no API-Version should return version 1")
    }),
    it("index returns 400 for an unknown API-Version", fn() {
      // Arrange
      let request = request_with_api_version([Header("API-Version", "3")])

      // Act
      let response =
        rest_api_guide_header_versioning.index(
          request,
          new_context("test"),
          rest_api_guide_header_versioning.Services,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(400)
      |> or_fail_with("API-Version 3 should return 400")
    }),
  ])
}

fn request_with_api_version(headers: List(Header)) -> Request {
  Request(..test_request.create_request(Get, "/products"), headers: headers)
}

fn rest_api_filtering_tests() -> UnitTest {
  let products = [
    rest_api_guide_filtering.Product("Lamp", "lighting", 30),
    rest_api_guide_filtering.Product("Desk", "furniture", 200),
    rest_api_guide_filtering.Product("Shelf", "furniture", 120),
    rest_api_guide_filtering.Product("Chair", "furniture", 80),
  ]
  describe("filtering and sorting", [
    it("index filters by category and price and sorts by price", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(
          Get,
          "/products",
          "category=furniture&max_price=150&sort=price",
        )
      let services = rest_api_guide_filtering.Services(products)

      // Act
      let response =
        rest_api_guide_filtering.index(request, new_context("test"), services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal(
        "[{\"name\":\"Chair\",\"category\":\"furniture\",\"price\":80},{\"name\":\"Shelf\",\"category\":\"furniture\",\"price\":120}]",
      )
      |> or_fail_with("index should return Chair, then Shelf")
    }),
    it("index sorts by name and keeps products at min_price", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(
          Get,
          "/products",
          "min_price=120",
        )
      let services = rest_api_guide_filtering.Services(products)

      // Act
      let response =
        rest_api_guide_filtering.index(request, new_context("test"), services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal(
        "[{\"name\":\"Desk\",\"category\":\"furniture\",\"price\":200},{\"name\":\"Shelf\",\"category\":\"furniture\",\"price\":120}]",
      )
      |> or_fail_with("index should return Desk, then Shelf")
    }),
  ])
}

fn rest_api_cors_tests() -> UnitTest {
  describe("cors", [
    it("cors_middleware adds the CORS headers before the existing ones", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products")

      // Act
      let response =
        rest_api_guide_cors.cors_middleware(
          request,
          new_context("test"),
          rest_api_guide_cors.Services,
          respond_with_request_id_header,
        )

      // Assert
      response.headers
      |> should()
      |> equal([
        Header("Access-Control-Allow-Origin", "*"),
        Header(
          "Access-Control-Allow-Methods",
          "GET, POST, PUT, DELETE, OPTIONS",
        ),
        Header("Access-Control-Allow-Headers", "Content-Type, Authorization"),
        Header("X-Request-Id", "test"),
      ])
      |> or_fail_with("cors_middleware should add three CORS headers")
    }),
  ])
}

fn respond_with_request_id_header(
  _request: Request,
  context: AppContext,
  _services: rest_api_guide_cors.Services,
) -> Response {
  let response = json_response(200, "{}")
  Response(..response, headers: [Header("X-Request-Id", context.request_id)])
}

// ============================================================================
// Helpers
// ============================================================================

pub type Socket

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "sse_guide_test_ffi", "open_stream")
fn open_stream(port: Int, path: String, timeout: Int) -> Result(Socket, String)

@external(erlang, "sse_guide_test_ffi", "read_until_events")
fn read_until_events(
  socket: Socket,
  received: BitArray,
  event_count: Int,
  timeout: Int,
) -> Result(BitArray, String)

@external(erlang, "sse_guide_test_ffi", "close")
fn close_socket(socket: Socket) -> Nil

/// Starts `app_router` on a free port, reads the response to GET `path`
/// until its body holds `event_count` events, and returns the whole response.
fn read_event_stream(
  app_router: Router(EmptyContext, services),
  services: services,
  path: String,
  event_count: Int,
) -> Result(String, String) {
  let port = free_port()
  case start_server(app_router, services, port) {
    Ok(handle) -> {
      let received = read_events_from(port, path, event_count)
      server.stop(handle)
      received
    }
    Error(message) -> Error(message)
  }
}

fn read_events_from(
  port: Int,
  path: String,
  event_count: Int,
) -> Result(String, String) {
  use socket <- result.try(open_stream(port, path, 2000))
  let received = read_until_events(socket, <<>>, event_count, 3000)
  close_socket(socket)
  result.try(received, bit_array_to_string)
}

/// Starts the broadcast controller, waits until its connection subscribes
/// to `event_bus`, publishes `text`, and returns the whole response.
fn read_broadcast_stream(
  event_bus: broadcaster.Broadcaster(sse_guide_broadcast.AppEvent),
  text: String,
) -> Result(String, String) {
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/events",
      controller: sse_guide_broadcast.handle_events,
      middleware: [],
    )
  let port = free_port()
  case start_server(app_router, event_bus, port) {
    Ok(handle) -> {
      let received = publish_and_read(port, event_bus, text)
      server.stop(handle)
      received
    }
    Error(message) -> Error(message)
  }
}

fn publish_and_read(
  port: Int,
  event_bus: broadcaster.Broadcaster(sse_guide_broadcast.AppEvent),
  text: String,
) -> Result(String, String) {
  use socket <- result.try(open_stream(port, "/events", 2000))
  let received = {
    use _count <- result.try(wait_for_one_subscriber(event_bus, 300))
    broadcaster.publish(event_bus, AppEvent(text))
    read_until_events(socket, <<>>, 1, 3000)
  }
  close_socket(socket)
  result.try(received, bit_array_to_string)
}

/// Asks `event_bus` for its subscriber count every 10 milliseconds until the
/// count is 1. The broadcaster handles a subscription before it answers a
/// later count request, so a count of 1 means the stream is subscribed.
fn wait_for_one_subscriber(
  event_bus: broadcaster.Broadcaster(sse_guide_broadcast.AppEvent),
  attempts_remaining: Int,
) -> Result(Int, String) {
  use count <- result.try(
    broadcaster.count_subscribers(event_bus)
    |> result.replace_error("the broadcaster did not report its subscribers"),
  )
  case count, attempts_remaining {
    1, _ -> Ok(count)
    _, attempts if attempts <= 1 ->
      Error("the stream did not subscribe to the broadcaster")
    _, attempts -> {
      process.sleep(10)
      wait_for_one_subscriber(event_bus, attempts - 1)
    }
  }
}

fn start_server(
  app_router: Router(EmptyContext, services),
  services: services,
  port: Int,
) -> Result(server.ServerHandle, String) {
  server.new()
  |> server.services(services)
  |> server.router(app_router)
  |> server.bind("127.0.0.1")
  |> server.listen_with_handle(port)
  |> result.replace_error("server did not start")
}

fn bit_array_to_string(bytes: BitArray) -> Result(String, String) {
  bit_array.to_string(bytes) |> result.replace_error("response is not UTF-8")
}

fn response_body(response: String) -> String {
  case string.split_once(response, "\r\n\r\n") {
    Ok(#(_head, body)) -> body
    Error(Nil) -> ""
  }
}

/// Finds the value of the header `name` (lower case) in the response head.
fn find_header(response: String, name: String) -> Result(String, Nil) {
  let head = case string.split_once(response, "\r\n\r\n") {
    Ok(#(head, _body)) -> head
    Error(Nil) -> response
  }
  head
  |> string.split("\r\n")
  |> list.find_map(fn(line) { match_header(line, name) })
}

fn match_header(line: String, name: String) -> Result(String, Nil) {
  case string.split_once(line, ": ") {
    Ok(#(header_name, value)) ->
      case string.lowercase(header_name) == name {
        True -> Ok(value)
        False -> Error(Nil)
      }
    Error(Nil) -> Error(Nil)
  }
}

/// A router whose GET /event sends the event given as services, once.
fn event_router() -> Router(EmptyContext, sse.Event) {
  router()
  |> route(method: Get, path: "/event", controller: serve_event, middleware: [])
}

fn serve_event(request, _context, event: sse.Event) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: event,
    on_init: init_event_stream,
    on_message: send_given_event,
  )
}

fn init_event_stream(
  subject: Subject(Nil),
  _event: sse.Event,
) -> #(Nil, option.Option(process.Selector(Nil))) {
  process.send(subject, Nil)
  #(Nil, None)
}

fn send_given_event(
  state: Nil,
  _message: Nil,
  connection: sse.SSEConnection,
  event: sse.Event,
) -> sse.Action(Nil, Nil) {
  sse_guide_events.send_event_or_stop(state, connection, event)
}
