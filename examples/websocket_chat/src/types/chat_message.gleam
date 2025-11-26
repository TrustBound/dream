/// Chat message types
///
/// Types representing chat events and messages in the WebSocket chat application.
pub type ChatMessage {
  TextMessage(user: String, text: String)
  UserJoined(user: String)
  UserLeft(user: String)
}
