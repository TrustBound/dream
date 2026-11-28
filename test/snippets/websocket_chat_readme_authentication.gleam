//// README example: examples/websocket_chat, "Pattern: Authentication in
//// WebSocket". The controller checks a token before it upgrades the
//// connection, and returns 401 when the token is missing or unknown.

import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/servers/mist/websocket
import gleam/erlang/process
import gleam/option
import gleam/result

pub type Dependencies {
  Dependencies(user: String)
}

pub fn handle_upgrade(
  request: Request,
  _context: context,
  _services: services,
) -> Response {
  case authenticate(request) {
    Ok(user) -> upgrade_for_user(request, user)
    Error(Nil) -> text_response(status.unauthorized, "Invalid auth token")
  }
}

pub fn authenticate(request: Request) -> Result(String, Nil) {
  get_query_param(request.query, "token")
  |> option.to_result(Nil)
  |> result.try(user_for_token)
}

fn user_for_token(token: String) -> Result(String, Nil) {
  case token {
    "token-for-ada" -> Ok("ada")
    _ -> Error(Nil)
  }
}

fn upgrade_for_user(request: Request, user: String) -> Response {
  websocket.upgrade_websocket(
    request,
    dependencies: Dependencies(user: user),
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn handle_init(
  _connection: websocket.Connection,
  dependencies: Dependencies,
) -> #(String, option.Option(process.Selector(String))) {
  #(dependencies.user, option.None)
}

fn handle_message(
  state: String,
  message: websocket.Message(String),
  connection: websocket.Connection,
  _dependencies: Dependencies,
) -> websocket.Action(String, String) {
  case message {
    websocket.TextMessage(text) -> {
      let _ = websocket.send_text(connection, state <> ": " <> text)
      websocket.continue_connection(state)
    }
    websocket.ConnectionClosed -> websocket.stop_connection()
    websocket.BinaryMessage(_) | websocket.CustomMessage(_) ->
      websocket.continue_connection(state)
  }
}

fn handle_close(_state: String, _dependencies: Dependencies) -> Nil {
  Nil
}
