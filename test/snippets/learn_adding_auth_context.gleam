//// Lesson 3: the custom context (src/context.gleam)

import gleam/option.{type Option, None}

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

pub const context = AuthContext(request_id: "", user: None)
