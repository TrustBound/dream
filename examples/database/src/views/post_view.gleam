//// Post view - presentation logic for posts
////
//// Pure formatting functions: Post → String
//// No Result types, no Response types, no error handling.

import dream_json/json_encoders as encoders
import gleam/json
import gleam/list
import gleam/option
import types/post.{type Post}

/// Format single post as JSON string
pub fn to_json(post: Post) -> String {
  to_json_object(post)
  |> json.to_string()
}

/// Format list of posts as JSON array string
pub fn list_to_json(posts: List(Post)) -> String {
  list.map(posts, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

// Private helpers - all named functions

fn to_json_object(post: Post) -> json.Json {
  json.object([
    #("id", json.int(post.id)),
    #("user_id", json.int(post.user_id)),
    #("title", json.string(post.title)),
    #("content", encoders.optional_string(post.content)),
    #("created_at", encoders.timestamp(option.Some(post.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}
