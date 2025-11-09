//// Export Posts Operation
////
//// Streaming CSV export of all posts.
//// Demonstrates streaming response pattern with clean code.

import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import gleam/yielder
import models/post/post as post_model
import services.{type Services}
import types/errors.{type DataError}
import types/post.{type Post, type PostStatus, Draft, Published}

/// Execute export operation
/// Returns a stream of CSV data
pub fn execute(
  services: Services,
) -> Result(yielder.Yielder(BitArray), DataError) {
  use posts <- result.try(post_model.list(services.db))
  Ok(create_csv_stream(posts))
}

fn create_csv_stream(posts: List(Post)) -> yielder.Yielder(BitArray) {
  let header = "id,title,author_id,status,created_at\n"
  let rows = list.map(posts, post_to_csv)
  
  yielder.from_list([header, ..rows])
  |> yielder.map(string_to_bits)
}

fn post_to_csv(post: Post) -> String {
  int.to_string(post.id)
  <> ","
  <> post.title
  <> ","
  <> int.to_string(post.author_id)
  <> ","
  <> status_to_string(post.status)
  <> ","
  <> timestamp_to_string(post.created_at)
  <> "\n"
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  string.inspect(ts)
}

fn string_to_bits(s: String) -> BitArray {
  <<s:utf8>>
}

// Private helper for CSV serialization

fn status_to_string(status: PostStatus) -> String {
  case status {
    Draft -> "draft"
    Published -> "published"
  }
}

