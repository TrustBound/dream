//// Example for the doc of `context.new_context`.

import dream/context.{type AppContext, new_context}

pub fn request_context() -> AppContext {
  // AppContext(request_id: "req-123")
  new_context("req-123")
}
