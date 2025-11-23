//// API Controller
////
//// Simple controller demonstrating rate-limited endpoints.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import services.{type Services}
import views/api_view

/// Index action - simple API endpoint
pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_index())
}

/// Status action - shows rate limit info
pub fn status(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_status())
}

/// Welcome action - public endpoint without rate limiting
pub fn welcome(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_welcome())
}
