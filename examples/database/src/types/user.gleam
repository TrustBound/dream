//// User domain type
////
//// Pure domain type - no serialization logic.

import gleam/time/timestamp.{type Timestamp}

pub type User {
  User(id: Int, name: String, email: String, created_at: Timestamp)
}
