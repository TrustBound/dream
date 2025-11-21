//// API view - presentation logic for rate limiter example
////
//// Pure formatting functions - no Response objects.

/// Format API endpoint message
pub fn format_index() -> String {
  "API endpoint - try making multiple requests!\n\nTry running:\n  for i in {1..15}; do curl http://localhost:3000/api; echo \"\"; done"
}

/// Format rate limit status message
pub fn format_status() -> String {
  "Rate Limiter Status\n\nThis endpoint is rate-limited.\nCheck the X-RateLimit-* headers in the response."
}

/// Format welcome message
pub fn format_welcome() -> String {
  "Welcome to the Singleton Rate Limiter Example!\n\nEndpoints:\n  GET /      - This welcome page (no rate limit)\n  GET /api   - Rate-limited API endpoint\n  GET /api/status - Rate limit status (also rate-limited)\n\nThe rate limiter uses the singleton pattern to maintain\nglobal state across all requests. Try making multiple\nrapid requests to /api to see it in action!"
}
