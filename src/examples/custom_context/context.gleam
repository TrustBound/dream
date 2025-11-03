//// Custom context type for authenticated requests
////
//// This module defines a custom context type that extends the basic
//// request context with authenticated user information.

import gleam/option

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: option.Option(User))
}

pub fn new_context(request_id: String) -> AuthContext {
  AuthContext(request_id: request_id, user: option.None)
}
