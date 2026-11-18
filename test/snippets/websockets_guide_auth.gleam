//// WebSockets guide: authentication at upgrade time
////
//// A controller that checks the auth token before it upgrades to a
//// WebSocket, as shown in docs/guides/websockets.md.

import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/http/status
import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/option.{None, Some}
import snippets/websockets_guide_chat.{
  type ChatMessage, Dependencies, handle_websocket_close, handle_websocket_init,
  handle_websocket_message,
}

pub type User {
  User(name: String, token: String)
}

pub type Services {
  Services(chat_bus: broadcaster.Broadcaster(ChatMessage), users: List(User))
}

pub fn handle_upgrade(request, _context, services: Services) -> Response {
  case validate_auth_token(request, services) {
    Ok(user) -> {
      let dependencies =
        Dependencies(user_name: user.name, chat_bus: services.chat_bus)
      websocket.upgrade_websocket(
        request,
        dependencies: dependencies,
        on_init: handle_websocket_init,
        on_message: handle_websocket_message,
        on_close: handle_websocket_close,
      )
    }
    Error(Nil) ->
      response.text_response(status.unauthorized, "Invalid auth token")
  }
}

/// Finds the user whose token is in the `Authorization: Bearer` header.
fn validate_auth_token(
  request: Request,
  services: Services,
) -> Result(User, Nil) {
  case get_header(request.headers, "Authorization") {
    Some("Bearer " <> token) -> find_user_by_token(services.users, token)
    Some(_other) -> Error(Nil)
    None -> Error(Nil)
  }
}

fn find_user_by_token(users: List(User), token: String) -> Result(User, Nil) {
  case users {
    [] -> Error(Nil)
    [user, ..] if user.token == token -> Ok(user)
    [_user, ..rest] -> find_user_by_token(rest, token)
  }
}
