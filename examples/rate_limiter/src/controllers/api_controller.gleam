//// API Controller
////
//// Simple controller demonstrating rate-limited endpoints.

import dream/core/context.{type AppContext}
import dream/core/http/response.{text_response}
import dream/core/http/status
import dream/core/http/transaction.{type Request, type Response}
import services.{type Services}
import views/api_view

/// Index action - simple API endpoint
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_index())
}

/// Status action - shows rate limit info
pub fn status(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_status())
}

/// Welcome action - public endpoint without rate limiting
pub fn welcome(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(status.ok, api_view.format_welcome())
}
