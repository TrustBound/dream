//// Application context for multi-format example

/// Application context holds per-request mutable data
pub type AppContext {
  AppContext(request_id: String)
}
