//// Post view - presentation logic for posts
////
//// This module handles all presentation concerns for post data,
//// converting model data into HTTP responses.

import dream/core/http/statuses.{
  created_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{type Response, json_response}
import gleam/json
import gleam/list
import models/post
import pog
import sql

/// Respond with a single post (for show action)
pub fn respond(
  result: Result(pog.Returned(sql.GetPostRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> {
      case returned.rows {
        [post] -> json_response(ok_status(), to_json(post))
        [] -> not_found_response()
        _ -> not_found_response()
      }
    }
    Error(_) -> not_found_response()
  }
}

/// Respond with a list of posts (for index action)
pub fn respond_list(
  result: Result(pog.Returned(sql.ListPostsRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> json_response(ok_status(), list_to_json(returned.rows))
    Error(_) -> error_response()
  }
}

/// Respond with a created post (for create action)
pub fn respond_created(
  result: Result(pog.Returned(sql.CreatePostRow), pog.QueryError),
) -> Response {
  case result {
    Ok(returned) -> {
      case returned.rows {
        [post] -> json_response(created_status(), to_json_created(post))
        [] -> error_response()
        _ -> error_response()
      }
    }
    Error(_) -> error_response()
  }
}

// Private helper functions

fn to_json(post: sql.GetPostRow) -> String {
  post.encode(post)
  |> json.to_string()
}

fn to_json_created(post: sql.CreatePostRow) -> String {
  post.encode_create(post)
  |> json.to_string()
}

fn list_to_json(posts: List(sql.ListPostsRow)) -> String {
  posts
  |> list.map(post.encode_list)
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

fn not_found_response() -> Response {
  json_response(not_found_status(), "{\"error\": \"Post not found\"}")
}

fn error_response() -> Response {
  json_response(
    statuses.internal_server_error_status(),
    "{\"error\": \"Internal server error\"}",
  )
}

