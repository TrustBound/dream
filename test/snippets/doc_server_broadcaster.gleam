//// Doc comment example: dream/services/broadcaster, the Broadcaster type.

import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, Some}
import gleam/otp/actor
import gleam/result

pub type ChatMessage {
  ChatMessage(String)
}

// In services.gleam
pub type Services {
  Services(chat_bus: broadcaster.Broadcaster(ChatMessage))
}

pub fn initialize() -> Result(Services, actor.StartError) {
  use chat_bus <- result.map(broadcaster.start_broadcaster())
  Services(chat_bus: chat_bus)
}

// In WebSocket init handler
fn handle_init(
  _connection: websocket.Connection,
  services: Services,
) -> #(Nil, Option(Selector(ChatMessage))) {
  let channel = broadcaster.subscribe(services.chat_bus)
  let selector = broadcaster.channel_to_selector(channel)
  #(Nil, Some(selector))
}

// Anywhere in your app
pub fn say_hello(services: Services) -> Nil {
  broadcaster.publish(services.chat_bus, ChatMessage("hello"))
}

/// A WebSocket that says hello to every subscriber when a client sends
/// any text, and passes each published message on to its client.
pub fn chat(request, _context, services: Services) {
  websocket.upgrade_websocket(
    request,
    dependencies: services,
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn handle_message(
  state: Nil,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  services: Services,
) -> websocket.Action(Nil, ChatMessage) {
  case message {
    websocket.TextMessage(_text) -> {
      say_hello(services)
      websocket.continue_connection(state)
    }
    websocket.CustomMessage(ChatMessage(text)) -> {
      let _ = websocket.send_text(connection, text)
      websocket.continue_connection(state)
    }
    websocket.BinaryMessage(_data) -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: Nil, _services: Services) -> Nil {
  Nil
}
