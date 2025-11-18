//// Application context - per-request data

/// Application context holds per-request mutable data
pub type TasksContext {
  TasksContext(request_id: String)
}

/// Create new context for each request
pub fn new() -> TasksContext {
  TasksContext(request_id: "")
}
