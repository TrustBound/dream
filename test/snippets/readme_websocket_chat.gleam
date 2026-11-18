//// README: WebSockets
////
//// A controller that upgrades to a WebSocket and echoes each text message
//// with the user's name, as shown in the root README.

import dream/http/request.{type Request, get_query_param}
import dream/servers/mist/websocket
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub type Dependencies {
  Dependencies(user_name: String)
}

pub fn chat(request, _context, _services) {
  websocket.upgrade_websocket(
    request,
    dependencies: make_dependencies(request),
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn make_dependencies(request: Request) -> Dependencies {
  let user_name =
    get_query_param(request.query, "user")
    |> option.unwrap("guest")
  Dependencies(user_name:)
}

fn handle_init(
  _connection: websocket.Connection,
  _deps: Dependencies,
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: websocket.Message(Nil),
  connection: websocket.Connection,
  deps: Dependencies,
) -> websocket.Action(Nil, Nil) {
  case message {
    websocket.TextMessage(text) -> {
      let _ = websocket.send_text(connection, deps.user_name <> ": " <> text)
      websocket.continue_connection(state)
    }
    websocket.ConnectionClosed -> websocket.stop_connection()
    _ -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: Nil, _deps: Dependencies) -> Nil {
  Nil
}
