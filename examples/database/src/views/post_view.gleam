//// Post view - presentation logic for posts
////
//// Pure formatting functions: Post → String
//// No Result types, no Response types, no error handling.

import dream_json/json_encoders.{optional_string}
import gleam/json.{type Json, array, int, object, string, to_string}
import gleam/list.{map}
import gleam/option.{type Option, unwrap}
import gleam/time/timestamp.{type Timestamp, system_time}
import models/post.{type Post}
import views/time_text

/// Format single post as JSON string
pub fn to_json(post: Post) -> String {
  to_json_object(post)
  |> to_string()
}

/// Format list of posts as JSON array string
pub fn list_to_json(posts: List(Post)) -> String {
  map(posts, to_json_object)
  |> array(from: _, of: identity)
  |> to_string()
}

// Private helpers - all named functions

fn to_json_object(post: Post) -> Json {
  object([
    #("id", int(post.id)),
    #("user_id", int(post.user_id)),
    #("title", string(post.title)),
    #("content", optional_string(post.content)),
    #("created_at", time_text.to_json(created_at(post.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}

// The created_at column has a default but can be NULL. A NULL time shows
// the current time.
fn created_at(value: Option(Timestamp)) -> Timestamp {
  unwrap(value, system_time())
}
