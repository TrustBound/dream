import controllers/chat
import controllers/home
import controllers/static_controller
import dream/http/request.{Get}
import dream/router.{route, router}

/// Create the application router
///
/// Sets up all routes for the chat application.
///
/// ## Example
///
/// ```gleam
/// let app_router = router.create()
/// ```
pub fn create() {
  router()
  |> route(Get, "/", home.show, [])
  |> route(Get, "/chat", chat.handle_chat_upgrade, [])
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
}
