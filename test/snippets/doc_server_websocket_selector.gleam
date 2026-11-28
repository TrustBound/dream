//// Example for the doc of `websocket.continue_connection_with_selector`.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub fn notifications(request: Request, _context, _services) -> Response {
  websocket.upgrade_websocket(
    request,
    dependencies: Nil,
    on_init: start,
    on_message: handle_message,
    on_close: close,
  )
}

fn start(
  _connection: websocket.Connection,
  _dependencies: Nil,
) -> #(Nil, Option(Selector(String))) {
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: websocket.Message(String),
  connection: websocket.Connection,
  _dependencies: Nil,
) -> websocket.Action(Nil, String) {
  case message {
    websocket.TextMessage("subscribe") -> subscribe(state)
    websocket.CustomMessage(text) -> forward(state, connection, text)
    _ -> websocket.continue_connection(state)
  }
}

fn subscribe(state: Nil) -> websocket.Action(Nil, String) {
  let notifications = process.new_subject()
  process.send(notifications, "You are subscribed")
  // From now on the loop also receives the messages sent to notifications
  let selector =
    process.new_selector()
    |> process.select(notifications)
  websocket.continue_connection_with_selector(state, selector)
}

fn forward(
  state: Nil,
  connection: websocket.Connection,
  text: String,
) -> websocket.Action(Nil, String) {
  case websocket.send_text(connection, text) {
    Ok(Nil) -> websocket.continue_connection(state)
    Error(_send_error) -> websocket.stop_connection()
  }
}

fn close(_state: Nil, _dependencies: Nil) -> Nil {
  Nil
}
