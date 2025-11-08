//// Post view - presentation logic for posts
////
//// This module handles all presentation concerns for post data,
//// converting model data into HTTP responses. All JSON encoding lives here.

import dream/core/http/statuses.{created_status, ok_status}
import dream/core/http/transaction.{type Response, json_response}
import dream/utilities/json/encoders
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog
import sql
import views/errors

/// Respond with a single post (for show action)
pub fn respond(
  result: Result(pog.Returned(sql.GetPostRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_with_rows(rows: List(sql.GetPostRow)) -> Response {
  case rows {
    [post] -> json_response(ok_status(), to_json(post))
    [] -> errors.not_found("Post not found")
    _ -> errors.not_found("Post not found")
  }
}

/// Respond with a list of posts (for index action)
pub fn respond_list(
  result: Result(pog.Returned(sql.ListPostsRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> json_response(ok_status(), list_to_json(returned.rows))
    Error(_) -> errors.internal_error()
  }
}

/// Respond with a created post (for create action)
pub fn respond_created(
  result: Result(pog.Returned(sql.CreatePostRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> respond_created_with_rows(returned.rows)
    Error(_) -> errors.internal_error()
  }
}

fn respond_created_with_rows(rows: List(sql.CreatePostRow)) -> Response {
  case rows {
    [post] -> json_response(created_status(), to_json_created(post))
    [] -> errors.internal_error()
    _ -> errors.internal_error()
  }
}

// Private helper functions - JSON encoding

fn to_json(post: sql.GetPostRow) -> String {
  encode_post(post.id, post.user_id, post.title, post.content, post.created_at)
  |> json.to_string()
}

fn to_json_created(post: sql.CreatePostRow) -> String {
  encode_post(post.id, post.user_id, post.title, post.content, post.created_at)
  |> json.to_string()
}

fn list_to_json(posts: List(sql.ListPostsRow)) -> String {
  posts
  |> list.map(fn(post) {
    encode_post(
      post.id,
      post.user_id,
      post.title,
      post.content,
      post.created_at,
    )
  })
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

/// Shared JSON encoder for all post row types
fn encode_post(
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
