//// User domain type

import gleam/time/timestamp.{type Timestamp}

pub type User {
  User(id: Int, username: String, email: String, created_at: Timestamp)
}

