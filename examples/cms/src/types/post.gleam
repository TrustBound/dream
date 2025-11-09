//// Post domain type
////
//// Pure domain type - no serialization logic.

import gleam/time/timestamp.{type Timestamp}

pub type Post {
  Post(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: PostStatus,
    created_at: Timestamp,
  )
}

pub type PostStatus {
  Draft
  Published
}
