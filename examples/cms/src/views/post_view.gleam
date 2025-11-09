//// Post view - formatting functions (serializer pattern)
////
//// Pure transformations: Post -> String
//// No Result types, no Response types, no error handling.

import dream_helpers/json_encoders
import gleam/int
import gleam/json
import gleam/list
import types/post.{type Post, type PostStatus, Draft, Published}

/// Format single post as JSON
pub fn to_json(post: Post) -> String {
  to_json_object(post)
  |> json.to_string()
}

/// Format list of posts as JSON array
pub fn list_to_json(posts: List(Post)) -> String {
  list.map(posts, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

/// Format post as CSV row
pub fn to_csv(post: Post) -> String {
  int.to_string(post.id)
  <> ","
  <> post.title
  <> ","
  <> int.to_string(post.author_id)
  <> ","
  <> status_to_string(post.status)
  <> ","
  <> json_encoders.timestamp_to_string(post.created_at)
}

/// Format post as HTML
pub fn to_html(post: Post) -> String {
  "<article>
    <h1>" <> post.title <> "</h1>
    <p>" <> post.content <> "</p>
    <footer>By author " <> int.to_string(post.author_id) <> " • " <> json_encoders.timestamp_to_string(post.created_at) <> "</footer>
  </article>"
}

// Private helpers

fn to_json_object(post: Post) -> json.Json {
  json.object([
    #("id", json.int(post.id)),
    #("title", json.string(post.title)),
    #("content", json.string(post.content)),
    #("author_id", json.int(post.author_id)),
    #("status", json.string(status_to_string(post.status))),
    #("created_at", json.string(json_encoders.timestamp_to_string(post.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}

// Private helper for serialization

fn status_to_string(status: PostStatus) -> String {
  case status {
    Draft -> "draft"
    Published -> "published"
  }
}

