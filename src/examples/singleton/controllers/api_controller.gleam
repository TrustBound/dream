//// API Controller
////
//// Simple controller demonstrating rate-limited endpoints.

import dream/core/context.{type AppContext}
import dream/core/http/statuses.{ok_status}
import dream/core/http/transaction.{type Request, type Response, text_response}
import examples/singleton/services.{type Services}

/// Index action - simple API endpoint
pub fn index(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(
    ok_status(),
    "API endpoint - try making multiple requests!\n\nTry running:\n  for i in {1..15}; do curl http://localhost:3000/api; echo \"\"; done",
  )
}

/// Status action - shows rate limit info
pub fn status(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(
    ok_status(),
    "Rate Limiter Status\n\nThis endpoint is rate-limited.\nCheck the X-RateLimit-* headers in the response.",
  )
}

/// Welcome action - public endpoint without rate limiting
pub fn welcome(
  _request: Request,
  _context: AppContext,
  _services: Services,
) -> Response {
  text_response(
    ok_status(),
    "Welcome to the Singleton Rate Limiter Example!\n\nEndpoints:\n  GET /      - This welcome page (no rate limit)\n  GET /api   - Rate-limited API endpoint\n  GET /api/status - Rate limit status (also rate-limited)\n\nThe rate limiter uses the singleton pattern to maintain\nglobal state across all requests. Try making multiple\nrapid requests to /api to see it in action!",
  )
}

