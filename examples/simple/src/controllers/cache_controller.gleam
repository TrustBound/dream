//// Cache controller
////
//// Answers PURGE, a method that is not in the HTTP standard. The router
//// matches it with Other("PURGE").

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type EmptyServices}

/// PURGE /cache
pub fn purge(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Cache purged")
}
