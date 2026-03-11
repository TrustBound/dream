//// Tests for dream/servers/mist/sse module.

import dream/servers/mist/sse
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/erlang/process

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("sse", [
    event_builder_tests(),
    action_tests(),
  ])
}

fn event_builder_tests() -> UnitTest {
  describe("event builders", [
    it("creates event with data", fn() {
      // Act
      let _ev = sse.event("hello")

      // Assert — compiles and returns an Event
      AssertionOk
    }),
    it("sets event name", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_name("greeting")

      // Assert — compiles and chains
      AssertionOk
    }),
    it("sets event id", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_id("1")

      // Assert — compiles and chains
      AssertionOk
    }),
    it("sets event retry", fn() {
      // Act
      let _ev =
        sse.event("hello")
        |> sse.event_retry(5000)

      // Assert — compiles and chains
      AssertionOk
    }),
    it("chains all event builder functions", fn() {
      // Act
      let _ev =
        sse.event("{\"count\": 1}")
        |> sse.event_name("tick")
        |> sse.event_id("42")
        |> sse.event_retry(3000)

      // Assert — full chain compiles
      AssertionOk
    }),
  ])
}

fn action_tests() -> UnitTest {
  describe("actions", [
    it("continue_connection wraps state", fn() {
      // Act
      let _action: sse.Action(Int, String) = sse.continue_connection(42)

      // Assert — compiles with correct type
      AssertionOk
    }),
    it("continue_connection_with_selector wraps state and selector", fn() {
      // Arrange
      let selector = process.new_selector()

      // Act
      let _action: sse.Action(Int, String) =
        sse.continue_connection_with_selector(42, selector)

      // Assert — compiles with correct type
      AssertionOk
    }),
    it("stop_connection returns an action", fn() {
      // Act
      let _action: sse.Action(Int, String) = sse.stop_connection()

      // Assert — compiles with correct type
      AssertionOk
    }),
  ])
}
