//// Doc comment example: dream/servers/mist/websocket, module "Example (echo
//// chat)".

import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import gleam/erlang/process
import gleam/option

pub type Dependencies {
  Dependencies(user_name: String)
}

pub fn handle_upgrade(request: Request, _context, _services) -> Response {
  let user = get_query_param(request.query, "user")
  let user = option.unwrap(user, "Anonymous")
  let dependencies = Dependencies(user_name: user)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn handle_init(
  _connection: websocket.Connection,
  _dependencies: Dependencies,
) -> #(String, option.Option(process.Selector(String))) {
  // Initial state is an empty string, no extra messages yet
  #("", option.None)
}

fn handle_message(
  state: String,
  message: websocket.Message(String),
  connection: websocket.Connection,
  dependencies: Dependencies,
) -> websocket.Action(String, String) {
  case message {
    websocket.TextMessage(text) -> {
      let reply = dependencies.user_name <> ": " <> text
      let _ = websocket.send_text(connection, reply)
      websocket.continue_connection(state)
    }
    websocket.ConnectionClosed -> websocket.stop_connection()
    _ -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: String, _dependencies: Dependencies) -> Nil {
  Nil
}
