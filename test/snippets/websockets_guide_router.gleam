//// WebSockets guide: the router
////
//// A router that sends GET /chat to the chat controller, as shown in
//// docs/guides/websockets.md.

import dream/http/request.{Get}
import dream/router.{route, router}
import snippets/websockets_guide_chat as chat

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/chat",
    controller: chat.handle_chat_upgrade,
    middleware: [],
  )
}
