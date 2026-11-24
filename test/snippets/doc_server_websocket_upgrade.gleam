//// Doc comment example: dream/servers/mist/websocket.upgrade_websocket

import dream/servers/mist/websocket
import gleam/option.{None}

pub fn connect(request, _context, services) {
  websocket.upgrade_websocket(
    request,
    dependencies: services,
    on_init: init_handler,
    on_message: message_handler,
    on_close: close_handler,
  )
}

fn init_handler(_connection, _services) {
  #(0, None)
}

fn message_handler(state, message, connection, _services) {
  case message {
    websocket.TextMessage(text) -> {
      // Handle text message
      let _ = websocket.send_text(connection, text)
      websocket.continue_connection(state + 1)
    }
    websocket.CustomMessage(custom_message) -> {
      // Handle custom message from selector
      let _ = websocket.send_text(connection, custom_message)
      websocket.continue_connection(state)
    }
    _ -> websocket.continue_connection(state)
  }
}

fn close_handler(_state, _services) {
  Nil
}
