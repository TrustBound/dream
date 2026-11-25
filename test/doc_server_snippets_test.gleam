//// Tests for the snippets shown in the doc comments of the
//// `dream/servers/mist` modules and `dream/services/broadcaster`. Each
//// snippet is in test/snippets/doc_server_*.gleam.
////
//// Examples whose `main` blocks forever (`server.listen`) are compiled, and
//// the router and services they pass to the server are run here.

import dream/context.{type EmptyContext}
import dream/dream
import dream/http/request.{Get, Post}
import dream/http/response
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import dream/servers/mist/sse
import dream/services/broadcaster
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/mist_connection
import fixtures/request as test_request
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/yielder
import matchers/extract_body_text.{extract_body_text}
import mist
import snippets/doc_server_bind
import snippets/doc_server_broadcaster
import snippets/doc_server_broadcaster_functions.{UserJoined}
import snippets/doc_server_context
import snippets/doc_server_convert_metadata
import snippets/doc_server_custom_context
import snippets/doc_server_handler_create
import snippets/doc_server_internal
import snippets/doc_server_listen
import snippets/doc_server_listen_with_handle
import snippets/doc_server_max_body_size
import snippets/doc_server_new
import snippets/doc_server_new_with_context
import snippets/doc_server_port_probe
import snippets/doc_server_quick_start
import snippets/doc_server_request_id
import snippets/doc_server_response_convert
import snippets/doc_server_router
import snippets/doc_server_services
import snippets/doc_server_shutdown_timeout
import snippets/doc_server_sse_events
import snippets/doc_server_sse_selector
import snippets/doc_server_sse_send
import snippets/doc_server_sse_stop
import snippets/doc_server_sse_ticker
import snippets/doc_server_sse_upgrade
import snippets/doc_server_stop
import snippets/doc_server_stop_gracefully
import snippets/doc_server_websocket_chat
import snippets/doc_server_websocket_selector
import snippets/doc_server_websocket_send
import snippets/doc_server_websocket_stop
import snippets/doc_server_websocket_upgrade

pub fn tests() -> TestSuite {
  describe("doc comment snippets for dream/servers/mist", [
    server_module_tests(),
    sse_module_tests(),
    websocket_module_tests(),
    adapter_module_tests(),
    broadcaster_module_tests(),
  ])
}

// ============================================================================
// dream/servers/mist/server
// ============================================================================

fn server_module_tests() -> UnitNode {
  group("dream/servers/mist/server", [
    it("quick start router answers GET /", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          doc_server_quick_start.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello from Dream")
      |> or_fail_with("GET / should return 'Hello from Dream'")
    }),
    it("custom context router greets the guest", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")
      let context =
        doc_server_custom_context.MyContext(
          request_id: "",
          user: None,
          session: doc_server_custom_context.empty_session(),
        )

      // Act
      let response =
        dream.route_request(
          doc_server_custom_context.create_router(),
          request,
          context,
          doc_server_custom_context.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello, guest")
      |> or_fail_with("GET / should return 'Hello, guest'")
    }),
    it("new simple router answers GET /", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(doc_server_new.my_router(), request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello from Dream")
      |> or_fail_with("GET / should return 'Hello from Dream'")
    }),
    it("new with context router answers with the services greeting", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")
      let context =
        doc_server_new_with_context.MyContext(request_id: "", user: None)

      // Act
      let response =
        dream.route_request(
          doc_server_new_with_context.my_router(),
          request,
          context,
          doc_server_new_with_context.my_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello from Dream")
      |> or_fail_with("GET / should return 'Hello from Dream'")
    }),
    it("context router greets the user in the context", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")
      let context =
        doc_server_context.MyContext(
          request_id: "",
          user: Some(doc_server_context.User(name: "Ada")),
        )

      // Act
      let response =
        dream.route_request(
          doc_server_context.my_router(),
          request,
          context,
          doc_server_context.my_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello, Ada")
      |> or_fail_with("GET / should return 'Hello, Ada'")
    }),
    it("services are available to controllers", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          doc_server_services.my_router(),
          request,
          Nil,
          doc_server_services.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("postgres://localhost/app")
      |> or_fail_with("GET / should return the database URL")
    }),
    it("router example answers GET /users/:id", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/users/7", [#("id", "7")])

      // Act
      let response =
        dream.route_request(
          doc_server_router.create_router(),
          request,
          doc_server_router.MyContext(request_id: ""),
          doc_server_router.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("User 7")
      |> or_fail_with("GET /users/7 should return 'User 7'")
    }),
    it("bind example router answers GET /", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          doc_server_bind.my_router(),
          request,
          Nil,
          doc_server_bind.my_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello from localhost")
      |> or_fail_with("GET / should return 'Hello from localhost'")
    }),
    it("max body size example router answers POST /upload", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Post, "/upload", "report.csv")

      // Act
      let response =
        dream.route_request(
          doc_server_max_body_size.my_router(),
          request,
          Nil,
          doc_server_max_body_size.my_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Received report.csv")
      |> or_fail_with("POST /upload should return 'Received report.csv'")
    }),
    it("listen example router answers GET /", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        dream.route_request(
          doc_server_listen.create_router(),
          request,
          Nil,
          doc_server_listen.initialize_services(),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello from Dream")
      |> or_fail_with("GET / should return 'Hello from Dream'")
    }),
    it("listen_with_handle example gets the body from a running server", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result = doc_server_listen_with_handle.test_server(port)

      // Assert
      result
      |> should()
      |> be_equal(Ok("test passed"))
      |> or_fail_with("test_server should return Ok(\"test passed\")")
    }),
    it("stop example starts and stops a server", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result = doc_server_stop.test_server(port)

      // Assert
      result
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("test_server should return Ok(Nil)")
    }),
    it("stop_gracefully example starts and stops a server", fn() {
      // Arrange
      let port = free_port()

      // Act
      let result = doc_server_stop_gracefully.serve_then_stop(port)

      // Assert
      result
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("serve_then_stop should return Ok(Nil)")
    }),
    it("shutdown_timeout example waits at most 8 seconds", fn() {
      // Act
      let timeout =
        dream.get_shutdown_timeout(doc_server_shutdown_timeout.app())

      // Assert
      timeout
      |> should()
      |> be_equal(8000)
      |> or_fail_with("the app should wait at most 8000 ms")
    }),
  ])
}

// ============================================================================
// dream/servers/mist/sse
// ============================================================================

fn sse_module_tests() -> UnitNode {
  group("dream/servers/mist/sse", [
    it("ticker sends the first tick event", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: doc_server_sse_ticker.handle_events,
          middleware: [],
        )

      // Act
      let body = serve_and_get(app_router, Nil, "/events")

      // Assert
      body
      |> should()
      |> be_equal("id: 0\nevent: tick\ndata: 0\n\n")
      |> or_fail_with("the ticker should send tick 0 first")
    }),
    it("upgrade_to_sse example sends a ping", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: doc_server_sse_upgrade.events,
          middleware: [],
        )

      // Act
      let body = serve_and_get(app_router, Nil, "/events")

      // Assert
      body
      |> should()
      |> be_equal("data: ping\n\n")
      |> or_fail_with("the stream should send one ping event")
    }),
    it("send_event example sends hello", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: doc_server_sse_send.hello,
          middleware: [],
        )

      // Act
      let body = serve_and_get(app_router, Nil, "/events")

      // Assert
      body
      |> should()
      |> be_equal("data: hello\n\n")
      |> or_fail_with("the stream should send one hello event")
    }),
    it("greeting event has a name, an id and a retry time", fn() {
      // Arrange
      let event = doc_server_sse_events.greeting_event()

      // Act
      let body = event_body(event)

      // Assert
      body
      |> should()
      |> be_equal("retry: 5000\nid: 1\nevent: greeting\ndata: hello world\n\n")
      |> or_fail_with("the greeting event should have all four fields")
    }),
    it("event sends its data", fn() {
      // Arrange
      let event = doc_server_sse_events.count_event()

      // Act
      let body = event_body(event)

      // Assert
      body
      |> should()
      |> be_equal("data: {\"count\": 42}\n\n")
      |> or_fail_with("the event should send its JSON data")
    }),
    it("event_name sets the event field", fn() {
      // Arrange
      let event = doc_server_sse_events.named_event()

      // Act
      let body = event_body(event)

      // Assert
      body
      |> should()
      |> be_equal("event: tick\ndata: payload\n\n")
      |> or_fail_with("the event should have the name tick")
    }),
    it("event_id sets the id field", fn() {
      // Arrange
      let event = doc_server_sse_events.numbered_event()

      // Act
      let body = event_body(event)

      // Assert
      body
      |> should()
      |> be_equal("id: 42\ndata: payload\n\n")
      |> or_fail_with("the event should have the id 42")
    }),
    it("event_retry sets the retry field", fn() {
      // Arrange
      let event = doc_server_sse_events.retry_event()

      // Act
      let body = event_body(event)

      // Assert
      body
      |> should()
      |> be_equal("retry: 5000\ndata: payload\n\n")
      |> or_fail_with("the event should have the retry time 5000")
    }),
    it(
      "stop_connection example sends three counts, then closes the stream",
      fn() {
        // Arrange
        let app_router =
          router()
          |> route(
            method: Get,
            path: "/events",
            controller: doc_server_sse_stop.countdown,
            middleware: [],
          )

        // Act
        let body = serve_and_get(app_router, Nil, "/events")

        // Assert
        body
        |> should()
        |> be_equal("data: 3\n\ndata: 2\n\ndata: 1\n\n")
        |> or_fail_with("the stream should count down from 3 to 1")
      },
    ),
    it("continue_connection_with_selector example sends the greeting", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: doc_server_sse_selector.greetings,
          middleware: [],
        )

      // Act
      let body = serve_and_get(app_router, Nil, "/events")

      // Assert
      body
      |> should()
      |> be_equal("data: hello\n\n")
      |> or_fail_with("the stream should send one hello event")
    }),
  ])
}

/// Sends the event in the services to the client once, then stops.
fn send_one_event(request, _context, event: sse.Event) {
  sse.upgrade_to_sse(
    request,
    dependencies: event,
    on_init: send_one_event_init,
    on_message: send_one_event_message,
  )
}

fn send_one_event_init(
  subject: Subject(Nil),
  _event: sse.Event,
) -> #(Nil, Option(Selector(Nil))) {
  process.send(subject, Nil)
  #(Nil, None)
}

fn send_one_event_message(
  _state: Nil,
  _message: Nil,
  connection: sse.SSEConnection,
  event: sse.Event,
) -> sse.Action(Nil, Nil) {
  let _ = sse.send_event(connection, event)
  sse.stop_connection()
}

fn event_body(event: sse.Event) -> String {
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/events",
      controller: send_one_event,
      middleware: [],
    )
  serve_and_get(app_router, event, "/events")
}

// ============================================================================
// dream/servers/mist/websocket
// ============================================================================

fn websocket_module_tests() -> UnitNode {
  group("dream/servers/mist/websocket", [
    it("echo chat replies with the user name", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/chat",
          controller: doc_server_websocket_chat.handle_upgrade,
          middleware: [],
        )

      // Act
      let reply = websocket_round_trip(app_router, Nil, "/chat?user=ada", "hi")

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(1, <<"ada: hi":utf8>>)))
      |> or_fail_with("the chat should reply 'ada: hi' in a text frame")
    }),
    it("upgrade_websocket example echoes text", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/socket",
          controller: doc_server_websocket_upgrade.connect,
          middleware: [],
        )

      // Act
      let reply = websocket_round_trip(app_router, Nil, "/socket", "echo me")

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(1, <<"echo me":utf8>>)))
      |> or_fail_with("the socket should echo 'echo me' in a text frame")
    }),
    it("send_text example sends Hello!", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/greeting",
          controller: doc_server_websocket_send.greeting,
          middleware: [],
        )

      // Act
      let reply = websocket_round_trip(app_router, Nil, "/greeting", "hi")

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(1, <<"Hello!":utf8>>)))
      |> or_fail_with("the socket should send 'Hello!' in a text frame")
    }),
    it("send_binary example sends a binary frame", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/data",
          controller: doc_server_websocket_send.data,
          middleware: [],
        )

      // Act
      let reply = websocket_round_trip(app_router, Nil, "/data", "bytes")

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(2, <<"bytes":utf8>>)))
      |> or_fail_with("the socket should send 'bytes' in a binary frame")
    }),
    it(
      "continue_connection_with_selector example forwards the notification",
      fn() {
        // Arrange
        let app_router =
          router()
          |> route(
            method: Get,
            path: "/notifications",
            controller: doc_server_websocket_selector.notifications,
            middleware: [],
          )

        // Act
        let reply =
          websocket_round_trip(app_router, Nil, "/notifications", "subscribe")

        // Assert
        reply
        |> should()
        |> be_equal(Ok(#(1, <<"You are subscribed":utf8>>)))
        |> or_fail_with(
          "the socket should send You are subscribed in a text frame",
        )
      },
    ),
    it("stop_connection example closes the socket after bye", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/conversation",
          controller: doc_server_websocket_stop.conversation,
          middleware: [],
        )

      // Act
      let reply = websocket_round_trip(app_router, Nil, "/conversation", "bye")

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(8, <<3, 232>>)))
      |> or_fail_with("the server should send a close frame with code 1000")
    }),
  ])
}

// ============================================================================
// dream/servers/mist/request, response and port_probe
// ============================================================================

fn adapter_module_tests() -> UnitNode {
  group("dream/servers/mist adapter modules", [
    it("generate_request_id returns the inspected process ID", fn() {
      // Arrange
      let expected = string.inspect(process.self())

      // Act
      let request_id = doc_server_request_id.new_request_id()

      // Assert
      request_id
      |> should()
      |> be_equal(expected)
      |> or_fail_with("the request ID should be the inspected process ID")
    }),
    it("convert keeps the JSON content type", fn() {
      // Arrange
      let user_json = "{\"name\":\"Ada\"}"

      // Act
      let mist_response =
        doc_server_response_convert.send_user(
          mist_connection.request(
            mist_connection.closed_connection(<<>>),
            http.Get,
            "/",
            [],
          ),
          user_json,
        )

      // Assert
      mist_response.headers
      |> should()
      |> be_equal([#("content-type", "application/json; charset=utf-8")])
      |> or_fail_with("convert should keep the JSON content type")
    }),
    it("convert sends a stream body as chunks", fn() {
      // Arrange
      let port = free_port()

      // Act
      let body = stream_through_mist(port)

      // Assert
      body
      |> should()
      |> be_equal("5\r\nhello\r\n0\r\n\r\n")
      |> or_fail_with("convert should send one chunk, then the end")
    }),
    it("is_in_use returns False for a free port", fn() {
      // Arrange
      let port = free_port()

      // Act
      let in_use = doc_server_port_probe.check_port(port)

      // Assert
      in_use
      |> should()
      |> be_equal(False)
      |> or_fail_with("a free port should not be in use")
    }),
    it("is_in_use returns True for a port with a listener", fn() {
      // Arrange
      let #(port, listener) = hold_port()

      // Act
      let in_use = doc_server_port_probe.check_port(port)
      release_port(listener)

      // Assert
      in_use
      |> should()
      |> be_equal(True)
      |> or_fail_with("a port with a listener should be in use")
    }),
    it("handler.create example answers GET / through Mist", fn() {
      // Act
      let body = get_from_handler_example("/")

      // Assert
      body
      |> should()
      |> be_equal("Hello")
      |> or_fail_with("the body should be Hello")
    }),
    it("convert_metadata example reads the method, path and query", fn() {
      // Act
      let body = mist_get(doc_server_convert_metadata.describe, "/users?page=2")

      // Assert
      body
      |> should()
      |> be_equal("GET /users?page=2")
      |> or_fail_with("the body should be GET /users?page=2")
    }),
    it("internal example reads back the stored value", fn() {
      // Act
      let value = doc_server_internal.stash_and_read()

      // Assert
      value
      |> should()
      |> be_equal("hello")
      |> or_fail_with("the stored value should be hello")
    }),
  ])
}

fn stream_through_mist(port: Int) -> String {
  let stream = yielder.from_list([<<"hello":utf8>>])
  let dream_response = response.stream_response(200, stream, "text/plain")
  let handler = fn(mist_request) {
    doc_server_response_convert.send_stream(mist_request, dream_response)
  }
  let started =
    mist.new(handler)
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start
  case started {
    Ok(started) -> {
      let received = request_until_closed(port, get_payload("/"), 300)
      process.send_exit(started.pid)
      response_body(received)
    }
    Error(_start_error) -> "server did not start"
  }
}

// ============================================================================
// dream/services/broadcaster
// ============================================================================

fn broadcaster_module_tests() -> UnitNode {
  group("dream/services/broadcaster", [
    it("module example passes a published message to a WebSocket", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/chat",
          controller: doc_server_broadcaster.chat,
          middleware: [],
        )
      let services = doc_server_broadcaster.initialize()

      // Act
      let reply =
        result.map_error(services, string.inspect)
        |> result.try(fn(services) {
          websocket_round_trip(app_router, services, "/chat", "hi")
        })

      // Assert
      reply
      |> should()
      |> be_equal(Ok(#(1, <<"hello":utf8>>)))
      |> or_fail_with("the WebSocket should receive the published hello")
    }),
    it("start_broadcaster returns a working broadcaster", fn() {
      // Arrange
      let started = doc_server_broadcaster_functions.start_chat_bus()

      // Act
      let received = result.map(started, publish_and_receive)

      // Assert
      received
      |> should()
      |> be_equal(Ok(Ok("hello")))
      |> or_fail_with("a subscriber should receive 'hello'")
    }),
    it("subscribe returns a selector for published messages", fn() {
      // Arrange
      let started = broadcaster.start_broadcaster()

      // Act
      let received =
        result.map(started, fn(chat_bus) {
          let selector = doc_server_broadcaster_functions.listen_to(chat_bus)
          broadcaster.publish(chat_bus, "hello")
          process.selector_receive(selector, 500)
        })

      // Assert
      received
      |> should()
      |> be_equal(Ok(Ok("hello")))
      |> or_fail_with("the selector should receive 'hello'")
    }),
    it("publish sends the message to subscribers", fn() {
      // Arrange
      let started = broadcaster.start_broadcaster()

      // Act
      let received =
        result.map(started, fn(chat_bus) {
          let selector =
            broadcaster.subscribe(chat_bus)
            |> broadcaster.channel_to_selector
          doc_server_broadcaster_functions.announce(chat_bus)
          process.selector_receive(selector, 500)
        })

      // Assert
      received
      |> should()
      |> be_equal(Ok(Ok(UserJoined("Alice"))))
      |> or_fail_with("the subscriber should receive UserJoined(\"Alice\")")
    }),
    it("unsubscribe stops messages to the channel", fn() {
      // Arrange
      let started = broadcaster.start_broadcaster()

      // Act
      let received =
        result.map(started, fn(chat_bus) {
          let channel = broadcaster.subscribe(chat_bus)
          let selector = broadcaster.channel_to_selector(channel)
          doc_server_broadcaster_functions.leave(chat_bus, channel)
          broadcaster.publish(chat_bus, "hello")
          process.selector_receive(selector, 100)
        })

      // Assert
      received
      |> should()
      |> be_equal(Ok(Error(Nil)))
      |> or_fail_with("an unsubscribed channel should receive nothing")
    }),
    it("channel_to_selector gives a selector for the initial state", fn() {
      // Arrange
      let started = broadcaster.start_broadcaster()

      // Act
      let received =
        result.map(started, fn(chat_bus) {
          let #(_state, selector) =
            doc_server_broadcaster_functions.initial_state(chat_bus)
          broadcaster.publish(chat_bus, "hello")
          receive_from(selector)
        })

      // Assert
      received
      |> should()
      |> be_equal(Ok(Ok("hello")))
      |> or_fail_with("the selector should receive 'hello'")
    }),
  ])
}

fn publish_and_receive(
  chat_bus: broadcaster.Broadcaster(String),
) -> Result(String, Nil) {
  let selector =
    broadcaster.subscribe(chat_bus)
    |> broadcaster.channel_to_selector
  broadcaster.publish(chat_bus, "hello")
  process.selector_receive(selector, 500)
}

fn receive_from(selector: Option(Selector(String))) -> Result(String, Nil) {
  case selector {
    Some(selector) -> process.selector_receive(selector, 500)
    None -> Error(Nil)
  }
}

// ============================================================================
// Helpers
// ============================================================================

/// Starts a server with the router and services on a free port, sends one
/// GET request, and returns the response body (the bytes after the headers).
fn serve_and_get(
  app_router: Router(EmptyContext, services),
  services: services,
  path: String,
) -> String {
  let port = free_port()
  let started =
    server.new()
    |> server.services(services)
    |> server.router(app_router)
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)
  case started {
    Ok(handle) -> {
      let received = request_until_closed(port, get_payload(path), 300)
      server.stop(handle)
      response_body(received)
    }
    Error(_start_error) -> "server did not start"
  }
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

/// Starts a Mist server with the handler on a free port, sends one GET
/// request, stops the server, and returns the response body.
fn mist_get(
  handler: fn(http_request.Request(mist.Connection)) ->
    http_response.Response(mist.ResponseData),
  path: String,
) -> String {
  let port = free_port()
  let started =
    mist.new(handler)
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start
  case started {
    Ok(started) -> {
      let received = request_until_closed(port, get_payload(path), 300)
      process.send_exit(started.pid)
      response_body(received)
    }
    Error(_start_error) -> "server did not start"
  }
}

/// Starts the server of the handler.create example on a free port, sends one
/// GET request, stops the server, and returns the response body.
fn get_from_handler_example(path: String) -> String {
  let port = free_port()
  case doc_server_handler_create.start(port) {
    Ok(started) -> {
      let received = request_until_closed(port, get_payload(path), 300)
      doc_server_handler_create.stop(started)
      response_body(received)
    }
    Error(_start_error) -> "server did not start"
  }
}

fn get_payload(path: String) -> BitArray {
  bit_array.from_string(
    "GET " <> path <> " HTTP/1.1\r\nHost: localhost\r\n\r\n",
  )
}

fn response_body(received: Result(BitArray, Dynamic)) -> String {
  let bytes = result.unwrap(received, <<>>)
  response_text(bytes)
  |> result.unwrap(bytes)
  |> bit_array.to_string
  |> result.unwrap("")
}

@external(erlang, "raw_http_ffi", "response_text")
fn response_text(received: BitArray) -> Result(BitArray, Nil)

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "doc_server_ffi", "hold_port")
fn hold_port() -> #(Int, Dynamic)

@external(erlang, "doc_server_ffi", "release_port")
fn release_port(listener: Dynamic) -> Nil

@external(erlang, "doc_server_ffi", "websocket_exchange")
fn websocket_exchange(
  port: Int,
  path: String,
  text: String,
  timeout: Int,
) -> Result(#(Int, BitArray), String)

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, Dynamic)
