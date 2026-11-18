//// README example: examples/websocket_chat, "Why No Closures?". This is the
//// pattern to avoid: the handlers are closures that capture `user` and
//// `services` from the controller.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import dream/services/broadcaster.{type Broadcaster}
import gleam/option.{Some}

pub type Services {
  Services(pubsub: Broadcaster(String))
}

pub fn handle_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user = option.unwrap(get_query_param(request.query, "user"), "Anonymous")

  // ❌ BAD: each handler captures `user` and `services` from this scope
  websocket.upgrade_websocket(
    request,
    dependencies: Nil,
    on_init: fn(_connection, _dependencies) {
      let channel = broadcaster.subscribe(services.pubsub)
      #(user, Some(broadcaster.channel_to_selector(channel)))
    },
    on_message: fn(state, message, connection, _dependencies) {
      case message {
        websocket.TextMessage(text) -> {
          broadcaster.publish(services.pubsub, user <> ": " <> text)
          websocket.continue_connection(state)
        }
        websocket.CustomMessage(chat_line) -> {
          let _ = websocket.send_text(connection, chat_line)
          websocket.continue_connection(state)
        }
        websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
          websocket.continue_connection(state)
      }
    },
    on_close: fn(_state, _dependencies) {
      broadcaster.publish(services.pubsub, user <> " left")
    },
  )
}
