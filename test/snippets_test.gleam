//// Test all snippets by actually running them
////
//// This ensures the snippet code examples are valid and work correctly.
//// Each snippet is in test/snippets/ and is shown, character for character,
//// in a README. If any snippet fails, the test fails with the error.

import dream/dream
import dream/http/request.{Get}
import dream/http/response.{type Response, Stream}
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/assertions/should.{be_ok, equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import fixtures/server_start.{with_server}
import gleam/bit_array
import gleam/erlang/atom
import gleam/option.{Some}
import gleam/yielder
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/readme_hello_server
import snippets/readme_json_api.{Services as JsonServices, User}
import snippets/readme_streaming.{Services as LogServices}
import snippets/readme_websocket_chat
import snippets/server_tls
import snippets/sse_action_builders
import snippets/sse_event_builders

pub fn tests() -> UnitTest {
  describe("snippets", [
    it("sse event builders", fn() {
      sse_event_builders.build_event()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed SSE event builder snippet")
    }),
    it("sse action builders", fn() {
      sse_action_builders.build_actions()
      |> should()
      |> be_ok()
      |> or_fail_with("Failed SSE action builder snippet")
    }),
    readme_hello_server_tests(),
    readme_json_api_tests(),
    readme_streaming_tests(),
    readme_websocket_chat_tests(),
    server_tls_tests(),
  ])
}

fn readme_hello_server_tests() -> UnitTest {
  describe("readme hello server", [
    it("GET / returns status 200", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(readme_hello_server.app_router(), request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(200)
      |> or_fail_with("GET / should return 200")
    }),
    it("GET / returns Hello, world!", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(readme_hello_server.app_router(), request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, world!")
      |> or_fail_with("GET / should return 'Hello, world!'")
    }),
  ])
}

fn readme_json_api_tests() -> UnitTest {
  describe("readme json api", [
    it("get_user returns user 1 as JSON", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/1")
      let services =
        JsonServices(db: [User(id: 2, name: "Bo"), User(id: 1, name: "Ada")])

      // Act
      let response = readme_json_api.get_user(request, Nil, services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":1,\"name\":\"Ada\"}")
      |> or_fail_with("get_user should return user 1 as JSON")
    }),
    it("get_user returns status 200 when user 1 exists", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/1")
      let services = JsonServices(db: [User(id: 1, name: "Ada")])

      // Act
      let response = readme_json_api.get_user(request, Nil, services)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(200)
      |> or_fail_with("get_user should return 200")
    }),
    it("get_user returns status 404 when user 1 is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/1")
      let services = JsonServices(db: [User(id: 2, name: "Bo")])

      // Act
      let response = readme_json_api.get_user(request, Nil, services)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(404)
      |> or_fail_with("get_user should return 404")
    }),
  ])
}

fn readme_streaming_tests() -> UnitTest {
  describe("readme streaming", [
    it("download_log streams each log line", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/log")
      let services = LogServices(log_store: ["first", "second"])

      // Act
      let response = readme_streaming.download_log(request, Nil, services)

      // Assert
      stream_body(response)
      |> should()
      |> equal(<<"first\nsecond\n":utf8>>)
      |> or_fail_with("download_log should stream 'first\\nsecond\\n'")
    }),
    it("download_log sets content type text/plain", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/log")
      let services = LogServices(log_store: ["first"])

      // Act
      let response = readme_streaming.download_log(request, Nil, services)

      // Assert
      response.content_type
      |> should()
      |> equal(Some("text/plain"))
      |> or_fail_with("download_log should set text/plain")
    }),
  ])
}

fn readme_websocket_chat_tests() -> UnitTest {
  describe("readme websocket chat", [
    it("echoes a text message with the user name", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result = chat_round_trip(port, "/chat?user=ada", "hello")

      // Assert
      result
      |> should()
      |> equal(Ok("ada: hello"))
      |> or_fail_with("chat should reply 'ada: hello'")
    }),
    it("uses guest when the user query parameter is missing", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result = chat_round_trip(port, "/chat", "hello")

      // Assert
      result
      |> should()
      |> equal(Ok("guest: hello"))
      |> or_fail_with("chat should reply 'guest: hello'")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn stream_body(response: Response) -> BitArray {
  case response.body {
    Stream(stream) -> stream |> yielder.to_list |> bit_array.concat
    _other -> <<>>
  }
}

/// Starts the snippet's `chat` controller on a real server, sends one text
/// frame over a WebSocket, and returns the server's reply.
fn chat_round_trip(
  port: Int,
  path: String,
  text: String,
) -> Result(String, String) {
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/chat",
      controller: readme_websocket_chat.chat,
      middleware: [],
    )
  let started =
    server.new()
    |> server.router(app_router)
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)
  case started {
    Ok(handle) -> {
      let reply = send_text_and_receive(port, path, text, 2000)
      server.stop(handle)
      reply
    }
    Error(_start_error) -> Error("server did not start")
  }
}

@external(erlang, "websocket_ffi", "send_text_and_receive")
fn send_text_and_receive(
  port: Int,
  path: String,
  text: String,
  timeout: Int,
) -> Result(String, String)

fn server_tls_tests() -> UnitTest {
  describe("server tls", [
    it("serves GET / over HTTP/2 with TLS", fn() {
      // Arrange
      let #(certfile, keyfile) = write_certificate("build/test_tls")
      let port = free_port()
      use handle <- with_server(port, fn() {
        server_tls.start(certfile, keyfile, port)
      })

      // Act
      let result = tls_request(port, atom.create("http2"), "/")
      server.stop(handle)

      // Assert
      result
      |> should()
      |> equal(Ok(#(atom.create("http2"), 200, <<"Hello over HTTPS":utf8>>)))
      |> or_fail_with("GET / should answer over HTTP/2 with TLS")
    }),
  ])
}

@external(erlang, "dream_tls_test_ffi", "write_certificate")
fn write_certificate(directory: String) -> #(String, String)

@external(erlang, "dream_tls_test_ffi", "request")
fn tls_request(
  port: Int,
  protocol: atom.Atom,
  path: String,
) -> Result(#(atom.Atom, Int, BitArray), Nil)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
