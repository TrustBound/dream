//// Post model - data access functions (repository pattern)
////
//// Returns domain types, not database-specific types.
//// Demonstrates clean pattern: no nested cases, no anonymous functions.

import dream_postgres/client as postgres
import gleam/list
import gleam/result
import models/post/sql
import types/errors.{type DataError, DatabaseError, NotFound}
import types/post.{type Post, type PostStatus, Draft, Post, Published}

/// Get a single post by ID
pub fn get(db: postgres.Connection, id: Int) -> Result(Post, DataError) {
  sql.get_post(db, id)
  |> result.map_error(to_data_error)
  |> result.try(extract_single_post)
}

/// List all posts
pub fn list(db: postgres.Connection) -> Result(List(Post), DataError) {
  sql.list_posts(db)
  |> result.map_error(to_data_error)
  |> result.map(extract_all_posts)
}

/// Create a new post
pub fn create(
  db: postgres.Connection,
  author_id: Int,
  title: String,
  content: String,
) -> Result(Post, DataError) {
  sql.create_post(db, title, content, author_id)
  |> result.map_error(to_data_error)
  |> result.try(extract_created_post)
}

/// Update a post
pub fn update(
  db: postgres.Connection,
  id: Int,
  title: String,
  content: String,
) -> Result(Post, DataError) {
  sql.update_post(db, title, content, id)
  |> result.map_error(to_data_error)
  |> result.try(extract_updated_post)
}

/// Publish a post (change status to published)
pub fn publish(db: postgres.Connection, id: Int) -> Result(Post, DataError) {
  sql.publish_post(db, id)
  |> result.map_error(to_data_error)
  |> result.try(extract_published_post)
}

// Private helpers - all named functions

fn extract_single_post(
  returned: postgres.Returned(sql.GetPostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(from_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_all_posts(returned: postgres.Returned(sql.ListPostsRow)) -> List(Post) {
  list.map(returned.rows, from_row_list)
}

fn extract_created_post(
  returned: postgres.Returned(sql.CreatePostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(from_create_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_updated_post(
  returned: postgres.Returned(sql.UpdatePostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(from_update_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_published_post(
  returned: postgres.Returned(sql.PublishPostRow),
) -> Result(Post, DataError) {
  case returned.rows {
    [row] -> Ok(from_publish_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn from_row(row: sql.GetPostRow) -> Post {
  Post(
    id: row.id,
    title: row.title,
    content: row.content,
    author_id: row.author_id,
    status: status_from_string(row.status),
    created_at: row.created_at,
  )
}

fn from_row_list(row: sql.ListPostsRow) -> Post {
  Post(
    id: row.id,
    title: row.title,
    content: row.content,
    author_id: row.author_id,
    status: status_from_string(row.status),
    created_at: row.created_at,
  )
}

fn from_create_row(row: sql.CreatePostRow) -> Post {
  Post(
    id: row.id,
    title: row.title,
    content: row.content,
    author_id: row.author_id,
    status: status_from_string(row.status),
    created_at: row.created_at,
  )
}

fn from_update_row(row: sql.UpdatePostRow) -> Post {
  Post(
    id: row.id,
    title: row.title,
    content: row.content,
    author_id: row.author_id,
    status: status_from_string(row.status),
    created_at: row.created_at,
  )
}

fn from_publish_row(row: sql.PublishPostRow) -> Post {
  Post(
    id: row.id,
    title: row.title,
    content: row.content,
    author_id: row.author_id,
    status: status_from_string(row.status),
    created_at: row.created_at,
  )
}

fn status_from_string(status: String) -> PostStatus {
  case status {
    "published" -> Published
    _ -> Draft
  }
}

fn to_data_error(_: postgres.QueryError) -> DataError {
  DatabaseError
}

// Private adapter functions for database serialization

fn status_to_string(status: PostStatus) -> String {
  case status {
    Draft -> "draft"
    Published -> "published"
  }
}

