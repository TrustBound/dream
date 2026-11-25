//// Post operations - Business logic for post management
////
//// This module contains pure domain logic for post operations.
//// It calls the functions that dream_model generated in models/post,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option
import gleam/result
import models/post.{type Post}
import utilities/response_helpers

/// Get a post by ID
pub fn get_post(db: Connection, id: Int) -> Result(Post, Error) {
  post.get(db, id)
  |> result.map_error(post_error)
}

/// List posts for a user
pub fn list_posts(db: Connection, user_id: Int) -> Result(List(Post), Error) {
  post.list(db, user_id)
  |> result.map_error(post_error)
}

/// Create a new post
pub fn create_post(
  db: Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(Post, Error) {
  post.create(db, user_id, title, option.Some(content))
  |> result.map_error(post_error)
}

/// The Dream error of a post model error, with the texts for the client.
fn post_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Post not found",
    conflicts: [],
  )
}
