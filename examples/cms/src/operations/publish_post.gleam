//// Publish Post Operation
////
//// Business logic for publishing a post.
//// Coordinates Postgres (update post) and OpenSearch (log event).
//// Demonstrates clean pattern: no nested cases, no anonymous functions.

import gleam/int
import gleam/option
import gleam/result
import models/event/event as event_model
import models/post/post as post_model
import services.{type Services}
import types/errors.{type DataError, Unauthorized}
import types/event.{Event, PostPublished}
import types/post.{type Post}

/// Execute publish operation
pub fn execute(
  post_id: Int,
  user_id: Int,
  services: Services,
) -> Result(Post, DataError) {
  use post <- result.try(post_model.get(services.db, post_id))
  use _ <- result.try(check_authorization(user_id, post))
  use published <- result.try(post_model.publish(services.db, post_id))
  
  let _ = log_publish_event(published, user_id, services)
  
  Ok(published)
}

fn check_authorization(user_id: Int, post: Post) -> Result(Nil, DataError) {
  case user_id == post.author_id {
    True -> Ok(Nil)
    False -> Error(Unauthorized)
  }
}

fn log_publish_event(post: Post, user_id: Int, services: Services) -> Result(Nil, DataError) {
  let publish_event = Event(
    id: generate_event_id(post.id, user_id),
    event_type: PostPublished,
    user_id: option.Some(user_id),
    post_id: option.Some(post.id),
    method: "POST",
    path: "/posts/" <> int.to_string(post.id) <> "/publish",
    status_code: 200,
    duration_ms: 0,
    timestamp: get_current_timestamp(),
  )
  
  // Log to OpenSearch (persistence)
  let _ = event_model.log(services.opensearch, publish_event)
  
  // Broadcast to SSE subscribers (real-time)
  let broadcast = services.events.broadcast
  broadcast(publish_event)
  
  Ok(Nil)
}

fn generate_event_id(post_id: Int, user_id: Int) -> String {
  "post-published-" <> int.to_string(post_id) <> "-" <> int.to_string(user_id)
}

fn get_current_timestamp() -> String {
  // Simple ISO timestamp
  "2024-01-01T00:00:00Z"
}

