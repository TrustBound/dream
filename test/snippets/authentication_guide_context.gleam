import gleam/option.{type Option, None}

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

// Default context for unauthenticated requests
pub const default_context = AuthContext(request_id: "", user: None)
