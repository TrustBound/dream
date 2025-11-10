//// API view - presentation logic for singleton example
////
//// This module handles all presentation concerns for the singleton example,
//// converting data into HTTP responses.

import dream_helpers/statuses.{ok_status}
import dream/core/http/transaction.{type Response}
import dream_helpers/http.{text_response}

/// Respond with API endpoint message
pub fn respond_index() -> Response {
  text_response(
    ok_status(),
    "API endpoint - try making multiple requests!\n\nTry running:\n  for i in {1..15}; do curl http://localhost:3000/api; echo \"\"; done",
  )
}

/// Respond with rate limit status message
pub fn respond_status() -> Response {
  text_response(
    ok_status(),
    "Rate Limiter Status\n\nThis endpoint is rate-limited.\nCheck the X-RateLimit-* headers in the response.",
  )
}

/// Respond with welcome message
pub fn respond_welcome() -> Response {
  text_response(
    ok_status(),
    "Welcome to the Singleton Rate Limiter Example!\n\nEndpoints:\n  GET /      - This welcome page (no rate limit)\n  GET /api   - Rate-limited API endpoint\n  GET /api/status - Rate limit status (also rate-limited)\n\nThe rate limiter uses the singleton pattern to maintain\nglobal state across all requests. Try making multiple\nrapid requests to /api to see it in action!",
  )
}

