//// Post model - data operations only
////
//// This module handles database operations and returns domain types.
//// Presentation logic (JSON encoding) lives in views/post_view.

import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog
import sql
import types/errors.{type DataError, DatabaseError, NotFound}
import types/post.{type Post, Post}

/// List all posts for a user
pub fn list(db: pog.Connection, user_id: Int) -> Result(List(Post), DataError) {
  case sql.list_posts(db, user_id) {
    Ok(returned) -> Ok(extract_all_posts(returned))
    Error(_) -> Error(DatabaseError)
  }
}

/// Get a single post by ID
pub fn get(db: pog.Connection, id: Int) -> Result(Post, DataError) {
  case sql.get_post(db, id) {
    Ok(returned) -> extract_first_post(returned)
    Error(_) -> Error(DatabaseError)
  }
}

/// Create a new post
pub fn create(
  db: pog.Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(Post, DataError) {
  case sql.create_post(db, user_id, title, content) {
    Ok(returned) -> extract_created_post(returned)
    Error(_) -> Error(DatabaseError)
  }
}

/// Decoder for post create requests
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(#(title, content))
}

// Private helpers - all named functions

fn extract_first_post(
  returned: pog.Returned(sql.GetPostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(row_to_post(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_all_posts(returned: pog.Returned(sql.ListPostsRow)) -> List(Post) {
  list.map(returned.rows, row_to_post_list)
}

fn extract_created_post(
  returned: pog.Returned(sql.CreatePostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(row_to_post_create(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn row_to_post(row: sql.GetPostRow) -> Post {
  Post(
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    content: row.content,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_post_list(row: sql.ListPostsRow) -> Post {
  Post(
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    content: row.content,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_post_create(row: sql.CreatePostRow) -> Post {
  Post(
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    content: row.content,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}
