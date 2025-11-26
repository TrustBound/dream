import dream/services/broadcaster
import types/chat_message.{type ChatMessage}

/// Chat PubSub service type
///
/// This is a type alias for a broadcaster specialized for chat messages.
/// The broadcaster handles all subscription and message distribution logic.
pub type ChatPubSub =
  broadcaster.Broadcaster(ChatMessage)

/// Initialize the chat pub/sub service
///
/// Creates a broadcaster that manages subscriptions and broadcasts messages
/// to all subscribed WebSocket connections.
///
/// ## Example
///
/// ```gleam
/// let pubsub = chat_service.init_chat_pubsub()
/// ```
pub fn init_chat_pubsub() -> ChatPubSub {
  let assert Ok(pubsub) = broadcaster.start_broadcaster()
  pubsub
}
