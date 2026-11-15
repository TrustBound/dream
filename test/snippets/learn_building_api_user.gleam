//// Lesson 2: the User domain type (src/types/user.gleam)

import gleam/time/timestamp.{type Timestamp}

pub type User {
  User(id: Int, name: String, email: String, created_at: Timestamp)
}
