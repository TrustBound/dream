//// WebSockets guide: a test of the chat's message handling
////
//// reply_to and handle_websocket_close are from
//// test/snippets/websockets_guide_chat.gleam. Neither takes a connection,
//// so the test needs no server. The test process subscribes to the chat
//// bus, so it receives what the handlers publish.

import dream/servers/mist/websocket
import dream/services/broadcaster
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process
import snippets/websockets_guide_chat.{
  type ChatMessage, ChatMessage, ChatState, Close, Dependencies, KeepOpen,
  SendText,
}

fn chat_bus() -> broadcaster.Broadcaster(ChatMessage) {
  let assert Ok(chat_bus) = broadcaster.start_broadcaster()
  chat_bus
}

/// Subscribes the test process, then returns what it receives in 100 ms.
fn published_by(
  chat_bus: broadcaster.Broadcaster(ChatMessage),
  action: fn() -> anything,
) -> Result(ChatMessage, Nil) {
  let selector =
    broadcaster.subscribe(chat_bus)
    |> broadcaster.channel_to_selector
  let _result = action()
  process.selector_receive(selector, 100)
}

pub fn tests() -> TestSuite {
  let state = ChatState(user_name: "ada")

  describe("chat handlers", [
    group("reply_to", [
      it("keeps the connection open after a text message", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.TextMessage("hello"),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(KeepOpen)
        |> or_fail_with("a text message should keep the connection open")
      }),
      it("publishes a text message with the user's name", fn() {
        // Arrange
        let bus = chat_bus()
        let dependencies = Dependencies(user_name: "ada", chat_bus: bus)

        // Act
        let published =
          published_by(bus, fn() {
            websockets_guide_chat.reply_to(
              state,
              websocket.TextMessage("hello"),
              dependencies,
            )
          })

        // Assert
        published
        |> should
        |> be_equal(Ok(ChatMessage(sender: "ada", content: "hello")))
        |> or_fail_with("every subscriber should get ada's message")
      }),
      it("ignores a binary message", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.BinaryMessage(<<1, 2, 3>>),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(KeepOpen)
        |> or_fail_with("a binary message should change nothing")
      }),
      it("sends a broadcast message to the client as text", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())
        let message = ChatMessage(sender: "bob", content: "hi")

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.CustomMessage(message),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(SendText("bob: hi"))
        |> or_fail_with("bob's message should go to the client as 'bob: hi'")
      }),
      it("closes when the connection ends", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.ConnectionClosed,
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(Close)
        |> or_fail_with("a closed connection should stop the handler")
      }),
    ]),
    group("handle_websocket_close", [
      it("tells the others that the user left", fn() {
        // Arrange
        let bus = chat_bus()
        let dependencies = Dependencies(user_name: "ada", chat_bus: bus)

        // Act
        let published =
          published_by(bus, fn() {
            websockets_guide_chat.handle_websocket_close(state, dependencies)
          })

        // Assert
        published
        |> should
        |> be_equal(
          Ok(ChatMessage(sender: "ada", content: "ada left the chat")),
        )
        |> or_fail_with("the others should get the leave message")
      }),
    ]),
  ])
}
