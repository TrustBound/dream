//// Doc comment examples: dream/servers/mist/websocket.send_text and
//// send_binary

import dream/servers/mist/websocket
import gleam/bit_array
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub fn send_greeting(
  state: Nil,
  connection: websocket.Connection,
) -> websocket.Action(Nil, Nil) {
  case websocket.send_text(connection, "Hello!") {
    Ok(Nil) -> websocket.continue_connection(state)
    Error(_reason) -> websocket.stop_connection()
  }
}

pub fn send_data(
  state: Nil,
  connection: websocket.Connection,
  data: BitArray,
) -> websocket.Action(Nil, Nil) {
  case websocket.send_binary(connection, data) {
    Ok(Nil) -> websocket.continue_connection(state)
    Error(_reason) -> websocket.stop_connection()
  }
}

/// Answers every text message with "Hello!".
pub fn greeting(request, _context, _services) {
  websocket.upgrade_websocket(
    request,
    dependencies: Nil,
    on_init: handle_init,
    on_message: handle_greeting_message,
    on_close: handle_close,
  )
}

/// Answers every text message with its bytes in a binary frame.
pub fn data(request, _context, _services) {
  websocket.upgrade_websocket(
    request,
    dependencies: Nil,
    on_init: handle_init,
    on_message: handle_data_message,
    on_close: handle_close,
  )
}

fn handle_init(
  _connection: websocket.Connection,
  _dependencies: Nil,
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_greeting_message(
  state: Nil,
  message: websocket.Message(Nil),
  connection: websocket.Connection,
  _dependencies: Nil,
) -> websocket.Action(Nil, Nil) {
  case message {
    websocket.TextMessage(_text) -> send_greeting(state, connection)
    _ -> websocket.continue_connection(state)
  }
}

fn handle_data_message(
  state: Nil,
  message: websocket.Message(Nil),
  connection: websocket.Connection,
  _dependencies: Nil,
) -> websocket.Action(Nil, Nil) {
  case message {
    websocket.TextMessage(text) ->
      send_data(state, connection, bit_array.from_string(text))
    _ -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: Nil, _dependencies: Nil) -> Nil {
  Nil
}
