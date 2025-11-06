//// Database Context
////
//// Custom context for database example - just tracks request_id

/// Database context for tracking per-request state
pub type DatabaseContext {
  DatabaseContext(request_id: String)
}

/// Template context with empty request_id
/// The request_id will be updated for each request
pub const context = DatabaseContext(request_id: "")
