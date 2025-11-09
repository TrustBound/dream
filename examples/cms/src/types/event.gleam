//// Event domain type for OpenSearch logging
////
//// Pure domain type - no serialization logic.

import gleam/option.{type Option}

pub type Event {
  Event(
    id: String,
    event_type: EventType,
    user_id: Option(Int),
    post_id: Option(Int),
    method: String,
    path: String,
    status_code: Int,
    duration_ms: Int,
    timestamp: String,
  )
}

pub type EventType {
  RequestCompleted
  PostPublished
  PostCreated
  UserCreated
}
