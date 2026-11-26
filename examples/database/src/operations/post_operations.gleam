//// Post operations - Business logic for post management
////
//// This module contains pure domain logic for post operations.
//// It calls the functions that dream_model generated in models/post,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{type Connection, type QueryError}
import gleam/option.{Some}
import gleam/result.{map_error}
import models/post.{type Post, create, get, list}

/// Get a post by ID
pub fn get_post(db: Connection, id: Int) -> Result(Post, Error) {
  get(db, id)
  |> map_error(post_error)
}

/// List posts for a user
pub fn list_posts(db: Connection, user_id: Int) -> Result(List(Post), Error) {
  list(db, user_id)
  |> map_error(post_error)
}

/// Create a new post
pub fn create_post(
  db: Connection,
  user_id: Int,
  title: String,
  content: String,
) -> Result(Post, Error) {
  create(db, user_id, title, Some(content))
  |> map_error(post_error)
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn post_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("Post not found")
    _ -> from_shared(model_error)
  }
}
