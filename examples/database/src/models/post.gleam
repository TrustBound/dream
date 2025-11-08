//// Post model - data operations only
////
//// This module handles database operations and input validation.
//// Presentation logic (JSON encoding) lives in views/post_view.

import sql
import gleam/dynamic/decode
import pog

/// List all posts for a user
pub fn list(
  db: pog.Connection,
  user_id: Int,
) -> Result(pog.Returned(sql.ListPostsRow), pog.QueryError) {
  sql.list_posts(db, user_id)
}

/// Get a single post by ID
pub fn get(
  db: pog.Connection,
  id: Int,
) -> Result(pog.Returned(sql.GetPostRow), pog.QueryError) {
  sql.get_post(db, id)
}

/// Create a new post
pub fn create(
  db: pog.Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(pog.Returned(sql.CreatePostRow), pog.QueryError) {
  sql.create_post(db, user_id, title, content)
}

/// Decoder for post create requests
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(#(title, content))
}
