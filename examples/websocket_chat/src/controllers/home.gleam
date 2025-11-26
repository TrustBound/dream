import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, html_response}
import dream/http/status
import services.{type Services}
import views/chat_view

/// Show the chat interface
///
/// Serves the HTML page for the WebSocket chat application.
pub fn show(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  html_response(status.ok, chat_view.render_page())
}
