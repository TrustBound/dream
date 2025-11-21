//// Post operations - Business logic for post management
////
//// This module contains pure domain logic for post operations.
//// It returns Result types with dream.Error.

import dream/http/error.{type Error}
import models/post as post_model
import pog.{type Connection}
import types/post.{type Post}

/// Get a post by ID
pub fn get_post(db: Connection, id: Int) -> Result(Post, Error) {
  post_model.get(db, id)
}

/// List posts for a user
pub fn list_posts(db: Connection, user_id: Int) -> Result(List(Post), Error) {
  post_model.list(db, user_id)
}

/// Create a new post
pub fn create_post(
  db: Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(Post, Error) {
  post_model.create(db, user_id, title, content)
}
