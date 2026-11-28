//// WebSockets guide: a chat controller
////
//// A controller that upgrades to a WebSocket and shares each message with
//// every connected user through a broadcaster, as shown in
//// docs/guides/websockets.md.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/erlang/process
import gleam/option.{Some}
import gleam/otp/actor

pub type ChatMessage {
  ChatMessage(sender: String, content: String)
}

pub type Dependencies {
  Dependencies(
    user_name: String,
    chat_bus: broadcaster.Broadcaster(ChatMessage),
  )
}

pub type Services {
  Services(chat_bus: broadcaster.Broadcaster(ChatMessage))
}

pub fn initialize() -> Result(Services, actor.StartError) {
  case broadcaster.start_broadcaster() {
    Ok(chat_bus) -> Ok(Services(chat_bus: chat_bus))
    Error(start_error) -> Error(start_error)
  }
}

pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user_name =
    get_query_param(request.query, "user")
    |> option.unwrap("Anonymous")

  let dependencies =
    Dependencies(user_name: user_name, chat_bus: services.chat_bus)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
}

// Per-connection state kept by Dream
pub type ChatState {
  ChatState(user_name: String)
}

pub fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: Dependencies,
) -> #(ChatState, option.Option(process.Selector(ChatMessage))) {
  // 1. Subscribe this connection to the broadcaster
  let channel = broadcaster.subscribe(dependencies.chat_bus)

  // 2. Turn channel into a Selector so we can receive messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Initial state for this WebSocket connection
  let state = ChatState(user_name: dependencies.user_name)

  #(state, Some(selector))
}

/// What one message makes the connection do. A plain function with no
/// connection, so a test can call it.
pub type Reply {
  SendText(String)
  KeepOpen
}

pub fn reply_to(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  dependencies: Dependencies,
) -> Reply {
  case message {
    // Text sent by this client: broadcast to everyone (including sender)
    websocket.TextMessage(text) -> {
      let chat_message = ChatMessage(sender: state.user_name, content: text)
      broadcaster.publish(dependencies.chat_bus, chat_message)
      KeepOpen
    }

    // Message broadcast from the server (via broadcaster)
    websocket.CustomMessage(chat_message) ->
      SendText(format_chat_message(chat_message))

    // Ignore binary for now
    websocket.BinaryMessage(_) -> KeepOpen
  }
}

pub fn handle_websocket_message(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: Dependencies,
) -> websocket.Action(ChatState, ChatMessage) {
  case reply_to(state, message, dependencies) {
    SendText(text) -> send_or_stop(state, connection, text)
    KeepOpen -> websocket.continue_connection(state)
  }
}

fn send_or_stop(
  state: ChatState,
  connection: websocket.Connection,
  text: String,
) -> websocket.Action(ChatState, ChatMessage) {
  case websocket.send_text(connection, text) {
    Ok(Nil) -> websocket.continue_connection(state)
    // The client has gone away
    Error(_send_error) -> websocket.stop_connection()
  }
}

pub fn handle_websocket_close(
  state: ChatState,
  dependencies: Dependencies,
) -> Nil {
  let leave_message =
    ChatMessage(
      sender: state.user_name,
      content: state.user_name <> " left the chat",
    )
  broadcaster.publish(dependencies.chat_bus, leave_message)
}

fn format_chat_message(chat_message: ChatMessage) -> String {
  chat_message.sender <> ": " <> chat_message.content
}

pub fn publish_chat_message(
  services: Services,
  sender: String,
  text: String,
) -> Nil {
  broadcaster.publish(services.chat_bus, ChatMessage(sender, text))
}
