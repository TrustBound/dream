//// README example: examples/websocket_chat, "Pattern: Routing WebSocket
//// Messages". Parses the chat's JSON format and sends each message type to
//// its own handler.

import gleam/dynamic/decode
import gleam/json
import gleam/result

pub type ChatEvent {
  TextMessage(user: String, text: String)
  UserJoined(user: String)
  UserLeft(user: String)
}

pub fn route_chat_event(json_text: String) -> String {
  case parse_chat_event(json_text) {
    Ok(TextMessage(user, text)) -> handle_text_message(user, text)
    Ok(UserJoined(user)) -> handle_user_joined(user)
    Ok(UserLeft(user)) -> handle_user_left(user)
    Error(Nil) -> "Unknown message"
  }
}

pub fn parse_chat_event(json_text: String) -> Result(ChatEvent, Nil) {
  json.parse(from: json_text, using: chat_event_decoder())
  |> result.replace_error(Nil)
}

fn chat_event_decoder() -> decode.Decoder(ChatEvent) {
  use event_type <- decode.field("type", decode.string)
  use user <- decode.field("user", decode.string)
  case event_type {
    "message" -> text_message_decoder(user)
    "joined" -> decode.success(UserJoined(user))
    "left" -> decode.success(UserLeft(user))
    _ -> decode.failure(UserLeft(user), expected: "ChatEvent")
  }
}

fn text_message_decoder(user: String) -> decode.Decoder(ChatEvent) {
  use text <- decode.field("text", decode.string)
  decode.success(TextMessage(user, text))
}

fn handle_text_message(user: String, text: String) -> String {
  user <> ": " <> text
}

fn handle_user_joined(user: String) -> String {
  user <> " joined the chat"
}

fn handle_user_left(user: String) -> String {
  user <> " left the chat"
}
