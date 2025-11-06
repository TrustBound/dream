//// Default application context type for Dream web framework
////
//// This module provides a default context type that can be used as-is
//// or extended by applications for their own context needs.

/// Default application context type
/// Applications can use this as-is or define their own context type
pub type AppContext {
  AppContext(request_id: String)
}

/// Create a new context with a request ID
pub fn new_context(request_id: String) -> AppContext {
  AppContext(request_id: request_id)
}
