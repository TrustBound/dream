import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/erlang/process
import gleam/json
import gleam/option.{Some}
import services.{type Services}
import types/chat_message.{type ChatMessage, TextMessage, UserJoined, UserLeft}

/// Dependencies for WebSocket handlers
///
/// Wraps user and services to pass them through to handlers.
type ChatDependencies {
  ChatDependencies(user: String, services: Services)
}

/// Handle WebSocket upgrade request for chat
///
/// Upgrades the HTTP request to a WebSocket connection and sets up
/// pub/sub messaging for the chat room.
pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user = request.get_query_param(request.query, "user")
  let user = option.unwrap(user, "Anonymous")

  let dependencies = ChatDependencies(user: user, services: services)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
}

/// Initialize WebSocket connection
///
/// Subscribes to the broadcaster and notifies other users of join.
fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> #(String, option.Option(process.Selector(ChatMessage))) {
  let ChatDependencies(user: user, services: services) = dependencies

  // 1. Subscribe to broadcaster
  let channel = broadcaster.subscribe(services.pubsub)

  // 2. Create selector for chat messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Notify join
  broadcaster.publish(services.pubsub, UserJoined(user))

  // Initial state is the username
  #(user, Some(selector))
}

/// Handle WebSocket messages
///
/// Processes text messages from the client and custom messages from the broadcaster.
fn handle_websocket_message(
  state: String,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> websocket.Action(String, ChatMessage) {
  let ChatDependencies(services: services, ..) = dependencies

  case message {
    websocket.TextMessage(text) -> {
      // Broadcast user message
      broadcaster.publish(services.pubsub, TextMessage(state, text))
      websocket.continue_connection(state)
    }
    websocket.CustomMessage(chat_message) -> {
      // Received from PubSub, send to client
      let json_message = format_chat_message_to_json(chat_message)
      let _ = websocket.send_text(connection, json.to_string(json_message))
      websocket.continue_connection(state)
    }
    websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
      websocket.continue_connection(state)
  }
}

/// Format a chat message to JSON
fn format_chat_message_to_json(chat_message: ChatMessage) -> json.Json {
  case chat_message {
    TextMessage(user, text) ->
      json.object([
        #("type", json.string("message")),
        #("user", json.string(user)),
        #("text", json.string(text)),
      ])
    UserJoined(user) ->
      json.object([
        #("type", json.string("joined")),
        #("user", json.string(user)),
      ])
    UserLeft(user) ->
      json.object([
        #("type", json.string("left")),
        #("user", json.string(user)),
      ])
  }
}

/// Handle WebSocket close
///
/// Notifies other users when a user leaves.
fn handle_websocket_close(state: String, dependencies: ChatDependencies) -> Nil {
  let ChatDependencies(services: services, ..) = dependencies
  broadcaster.publish(services.pubsub, UserLeft(state))
}
