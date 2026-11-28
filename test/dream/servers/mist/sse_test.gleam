//// Tests for dream/servers/mist/sse module.

import dream/http/request.{type Request, Get}
import dream/http/response.{type Response}
import dream/router.{route, router}
import dream/servers/mist/server
import dream/servers/mist/sse
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import dream_test/unit.{type UnitNode, describe, group, it}
import gleam/bit_array
import gleam/erlang/process.{type Selector, type Subject}
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("sse", [
    event_builder_tests(),
    action_tests(),
    upgrade_tests(),
  ])
}

fn event_builder_tests() -> UnitNode {
  group("event builders", [
    it("creates event with data", fn() {
      // Act
      let _ev = sse.event("hello")

      // Assert — compiles and returns an Event
      Ok(AssertionOk)
    }),
    it("sets event name", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_name("greeting")

      // Assert — compiles and chains
      Ok(AssertionOk)
    }),
    it("sets event id", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_id("1")

      // Assert — compiles and chains
      Ok(AssertionOk)
    }),
    it("sets event retry", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_retry(5000)

      // Assert — compiles and chains
      Ok(AssertionOk)
    }),
    it("chains all event builder functions", fn() {
      // Act
      let _ev =
        sse.event("{\"count\": 1}")
        |> sse.event_name("tick")
        |> sse.event_id("42")
        |> sse.event_retry(3000)

      // Assert — full chain compiles
      Ok(AssertionOk)
    }),
  ])
}

fn action_tests() -> UnitNode {
  group("actions", [
    it("continue_connection wraps state", fn() {
      // Act
      let _action: sse.Action(Int, String) = sse.continue_connection(42)

      // Assert — compiles with correct type
      Ok(AssertionOk)
    }),
    it("continue_connection_with_selector wraps state and selector", fn() {
      // Arrange
      let selector = process.new_selector()

      // Act
      let _action: sse.Action(Int, String) =
        sse.continue_connection_with_selector(42, selector)

      // Assert — compiles with correct type
      Ok(AssertionOk)
    }),
    it("stop_connection returns an action", fn() {
      // Act
      let _action: sse.Action(Int, String) = sse.stop_connection()

      // Assert — compiles with correct type
      Ok(AssertionOk)
    }),
  ])
}

fn upgrade_tests() -> UnitNode {
  group("upgrade_to_sse", [
    it("delivers messages from the selector that on_init returns", fn() {
      // Arrange
      let port = free_port()
      use handle <- with_selector_server(port)
      let http_request = <<
        "GET /events HTTP/1.1\r\nhost: 127.0.0.1\r\n\r\n":utf8,
      >>

      // Act
      let result = read_events(port, http_request, 1, 2000)
      server.stop(handle)

      // Assert
      case result {
        Ok(<<"data: from-selector\n\n":utf8>>) -> Ok(AssertionOk)
        Ok(body) ->
          assertion_failed(
            "selector_event",
            "Expected body 'data: from-selector\\n\\n', got "
              <> string.inspect(bit_array.to_string(body)),
          )
        Error(reason) ->
          assertion_failed(
            "selector_event",
            "Expected the selector event, the read failed: " <> reason,
          )
      }
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

pub type SelectorDeps {
  SelectorDeps
}

fn selector_events_controller(
  request: Request,
  _context,
  _services,
) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: SelectorDeps,
    on_init: init_with_selector,
    on_message: send_message_as_event,
  )
}

// Sends nothing to the actor's own subject. The only message goes to a
// separate subject that only the returned selector receives from.
fn init_with_selector(
  _subject: Subject(String),
  _deps: SelectorDeps,
) -> #(Nil, Option(Selector(String))) {
  let side_subject = process.new_subject()
  process.send(side_subject, "from-selector")
  let selector = process.new_selector() |> process.select(side_subject)
  #(Nil, Some(selector))
}

fn send_message_as_event(
  state: Nil,
  message: String,
  connection: sse.SSEConnection,
  _deps: SelectorDeps,
) -> sse.Action(Nil, String) {
  let _ = sse.send_event(connection, sse.event(message))
  sse.continue_connection(state)
}

fn with_selector_server(
  port: Int,
  test_fn: fn(server.ServerHandle) -> Result(AssertionResult, String),
) -> Result(AssertionResult, String) {
  let result =
    server.new()
    |> server.router(
      router()
      |> route(
        method: Get,
        path: "/events",
        controller: selector_events_controller,
        middleware: [],
      ),
    )
    |> server.listen_with_handle(port)

  case result {
    Ok(handle) -> test_fn(handle)
    Error(start_error) ->
      assertion_failed(
        "with_selector_server",
        "Failed to start server on port "
          <> string.inspect(port)
          <> ": "
          <> string.inspect(start_error),
      )
  }
}

fn assertion_failed(
  operator: String,
  message: String,
) -> Result(AssertionResult, String) {
  Ok(
    AssertionFailed(AssertionFailure(
      operator: operator,
      message: message,
      payload: None,
    )),
  )
}

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "raw_http_ffi", "read_events")
fn read_events(
  port: Int,
  request: BitArray,
  event_count: Int,
  timeout_ms: Int,
) -> Result(BitArray, String)
