//// Example for the doc of `websocket.stop_connection`.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub fn conversation(request: Request, _context, _services) -> Response {
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
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: websocket.Message(Nil),
  _connection: websocket.Connection,
  _dependencies: Nil,
) -> websocket.Action(Nil, Nil) {
  case message {
    // The client sent "bye": stop the loop, and the server closes the socket
    websocket.TextMessage("bye") -> websocket.stop_connection()
    _ -> websocket.continue_connection(state)
  }
}

fn close(_state: Nil, _dependencies: Nil) -> Nil {
  Nil
}
