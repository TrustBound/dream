//// Post model - data operations and transformations
////
//// This module encapsulates all post-related data operations including
//// database queries, request validation, and response encoding.

import dream/utilities/json/encoders
import examples/database/sql
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp
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

/// JSON encoder for GetPostRow
pub fn encode(post: sql.GetPostRow) -> json.Json {
  encode_post_fields(
    post.id,
    post.user_id,
    post.title,
    post.content,
    post.created_at,
  )
}

/// JSON encoder for ListPostsRow
pub fn encode_list(post: sql.ListPostsRow) -> json.Json {
  encode_post_fields(
    post.id,
    post.user_id,
    post.title,
    post.content,
    post.created_at,
  )
}

/// JSON encoder for CreatePostRow
pub fn encode_create(post: sql.CreatePostRow) -> json.Json {
  encode_post_fields(
    post.id,
    post.user_id,
    post.title,
    post.content,
    post.created_at,
  )
}

fn encode_post_fields(
  id: Int,
  user_id: Int,
  title: String,
  content: option.Option(String),
  created_at: option.Option(timestamp.Timestamp),
) -> json.Json {
  json.object([
    #("id", json.int(id)),
    #("user_id", json.int(user_id)),
    #("title", json.string(title)),
    #("content", encoders.optional_string(content)),
    #("created_at", encoders.timestamp(created_at)),
  ])
}
