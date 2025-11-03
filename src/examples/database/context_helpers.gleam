//// Context Helpers
////
//// Helper functions for working with database context

import examples/database/context.{type DatabaseContext}

/// Update context with a new request_id
pub fn update_request_id(
  _context: DatabaseContext,
  request_id: String,
) -> DatabaseContext {
  context.DatabaseContext(request_id: request_id)
}
