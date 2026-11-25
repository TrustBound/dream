//// Post operations - Business logic for post management
////
//// This module contains pure domain logic for post operations.
//// It calls the functions that dream_model generated in models/post,
//// which return Result types with dream.Error.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option
import models/post.{type Post}

/// Get a post by ID
pub fn get_post(db: Connection, id: Int) -> Result(Post, Error) {
  post.get(db, id)
}

/// List posts for a user
pub fn list_posts(db: Connection, user_id: Int) -> Result(List(Post), Error) {
  post.list(db, user_id)
}

/// Create a new post
pub fn create_post(
  db: Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(Post, Error) {
  post.create(db, user_id, title, option.Some(content))
}
