//// Tests for the snippets shown in examples/websocket_chat/README.md. Each
//// snippet is in test/snippets/websocket_chat_readme_*.gleam.

import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import dream/services/broadcaster
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/result
import matchers/extract_body_text.{extract_body_text}
import snippets/websocket_chat_readme_authentication
import snippets/websocket_chat_readme_closure.{Services}
import snippets/websocket_chat_readme_message_routing.{
  TextMessage, UserJoined, UserLeft,
}

pub fn tests() -> UnitTest {
  describe("websocket_chat README snippets", [
    closure_tests(),
    message_routing_tests(),
    authentication_tests(),
  ])
}

fn closure_tests() -> UnitTest {
  describe("closure example", [
    it("broadcasts a text message back to the sender", fn() {
      // Arrange
      let started = broadcaster.start_broadcaster()

      // Act
      let reply = result.map(started, closure_round_trip)

      // Assert
      reply
      |> should()
      |> equal(Ok(Ok(#(1, <<"ada: hi":utf8>>))))
      |> or_fail_with("the closure example should reply 'ada: hi'")
    }),
  ])
}

fn closure_round_trip(
  pubsub: broadcaster.Broadcaster(String),
) -> Result(#(Int, BitArray), String) {
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/chat",
      controller: websocket_chat_readme_closure.handle_upgrade,
      middleware: [],
    )
  websocket_round_trip(
    app_router,
    Services(pubsub: pubsub),
    "/chat?user=ada",
    "hi",
  )
}

fn message_routing_tests() -> UnitTest {
  describe("message routing", [
    it("parses a message event", fn() {
      // Arrange
      let json_text =
        "{\"type\":\"message\",\"user\":\"Alice\",\"text\":\"hi\"}"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Ok(TextMessage("Alice", "hi")))
      |> or_fail_with("a message event should parse to TextMessage")
    }),
    it("parses a joined event", fn() {
      // Arrange
      let json_text = "{\"type\":\"joined\",\"user\":\"Alice\"}"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Ok(UserJoined("Alice")))
      |> or_fail_with("a joined event should parse to UserJoined")
    }),
    it("parses a left event", fn() {
      // Arrange
      let json_text = "{\"type\":\"left\",\"user\":\"Alice\"}"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Ok(UserLeft("Alice")))
      |> or_fail_with("a left event should parse to UserLeft")
    }),
    it("rejects an unknown type", fn() {
      // Arrange
      let json_text = "{\"type\":\"typing\",\"user\":\"Alice\"}"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Error(Nil))
      |> or_fail_with("an unknown type should not parse")
    }),
    it("rejects a message event with no text", fn() {
      // Arrange
      let json_text = "{\"type\":\"message\",\"user\":\"Alice\"}"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Error(Nil))
      |> or_fail_with("a message event with no text should not parse")
    }),
    it("rejects text that is not JSON", fn() {
      // Arrange
      let json_text = "hello"

      // Act
      let event =
        websocket_chat_readme_message_routing.parse_chat_event(json_text)

      // Assert
      event
      |> should()
      |> equal(Error(Nil))
      |> or_fail_with("text that is not JSON should not parse")
    }),
    it("routes a message event to the text handler", fn() {
      // Arrange
      let json_text =
        "{\"type\":\"message\",\"user\":\"Alice\",\"text\":\"hi\"}"

      // Act
      let reply =
        websocket_chat_readme_message_routing.route_chat_event(json_text)

      // Assert
      reply
      |> should()
      |> equal("Alice: hi")
      |> or_fail_with("a message event should route to 'Alice: hi'")
    }),
    it("routes a joined event to the joined handler", fn() {
      // Arrange
      let json_text = "{\"type\":\"joined\",\"user\":\"Alice\"}"

      // Act
      let reply =
        websocket_chat_readme_message_routing.route_chat_event(json_text)

      // Assert
      reply
      |> should()
      |> equal("Alice joined the chat")
      |> or_fail_with("a joined event should route to 'Alice joined the chat'")
    }),
    it("routes a left event to the left handler", fn() {
      // Arrange
      let json_text = "{\"type\":\"left\",\"user\":\"Alice\"}"

      // Act
      let reply =
        websocket_chat_readme_message_routing.route_chat_event(json_text)

      // Assert
      reply
      |> should()
      |> equal("Alice left the chat")
      |> or_fail_with("a left event should route to 'Alice left the chat'")
    }),
    it("routes bad input to the unknown reply", fn() {
      // Arrange
      let json_text = "hello"

      // Act
      let reply =
        websocket_chat_readme_message_routing.route_chat_event(json_text)

      // Assert
      reply
      |> should()
      |> equal("Unknown message")
      |> or_fail_with("bad input should route to 'Unknown message'")
    }),
  ])
}

fn authentication_tests() -> UnitTest {
  describe("authentication", [
    it("finds the user for a known token", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(
          Get,
          "/chat",
          "token=token-for-ada",
        )

      // Act
      let user = websocket_chat_readme_authentication.authenticate(request)

      // Assert
      user
      |> should()
      |> equal(Ok("ada"))
      |> or_fail_with("token-for-ada should belong to ada")
    }),
    it("rejects an unknown token", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(Get, "/chat", "token=wrong")

      // Act
      let user = websocket_chat_readme_authentication.authenticate(request)

      // Assert
      user
      |> should()
      |> equal(Error(Nil))
      |> or_fail_with("an unknown token should not authenticate")
    }),
    it("returns 401 when the token is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/chat")

      // Act
      let response =
        websocket_chat_readme_authentication.handle_upgrade(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(401)
      |> or_fail_with("a request with no token should get 401")
    }),
    it("returns 401 for an unknown token", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(Get, "/chat", "token=wrong")

      // Act
      let response =
        websocket_chat_readme_authentication.handle_upgrade(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(401)
      |> or_fail_with("a request with an unknown token should get 401")
    }),
    it("says why the request is rejected", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/chat")

      // Act
      let response =
        websocket_chat_readme_authentication.handle_upgrade(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Invalid auth token")
      |> or_fail_with("the 401 body should be 'Invalid auth token'")
    }),
    it("upgrades the connection for a known token", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/chat",
          controller: websocket_chat_readme_authentication.handle_upgrade,
          middleware: [],
        )

      // Act
      let reply =
        websocket_round_trip(app_router, Nil, "/chat?token=token-for-ada", "hi")

      // Assert
      reply
      |> should()
      |> equal(Ok(#(1, <<"ada: hi":utf8>>)))
      |> or_fail_with("an authenticated socket should reply 'ada: hi'")
    }),
  ])
}

/// Starts a server with the router and services on a free port, opens a
/// WebSocket at the path, sends one text frame, and returns the opcode and
/// payload of the first frame the server sends back.
fn websocket_round_trip(
  app_router: Router(EmptyContext, services),
  services: services,
  path: String,
  text: String,
) -> Result(#(Int, BitArray), String) {
  let port = free_port()
  let started =
    server.new()
    |> server.services(services)
    |> server.router(app_router)
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)
  case started {
    Ok(handle) -> {
      let reply = websocket_exchange(port, path, text, 2000)
      server.stop(handle)
      reply
    }
    Error(_start_error) -> Error("server did not start")
  }
}

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "doc_server_ffi", "websocket_exchange")
fn websocket_exchange(
  port: Int,
  path: String,
  text: String,
  timeout: Int,
) -> Result(#(Int, BitArray), String)
