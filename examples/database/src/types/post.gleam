//// Post domain type
////
//// Pure domain type - no serialization logic.

import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}

pub type Post {
  Post(
    id: Int,
    user_id: Int,
    title: String,
    content: Option(String),
    created_at: Timestamp,
  )
}
