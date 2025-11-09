//// Event view - formatting functions (serializer pattern)
////
//// Pure transformations: Event -> String
//// No Result types, no Response types, no error handling.

import gleam/int
import gleam/json
import gleam/list
import gleam/option
import types/event.{
  type Event, type EventType, PostCreated, PostPublished, RequestCompleted,
  UserCreated,
}

/// Format single event as JSON
pub fn to_json(event: Event) -> String {
  to_json_object(event)
  |> json.to_string()
}

/// Format list of events as JSON array
pub fn list_to_json(events: List(Event)) -> String {
  list.map(events, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

// Private helpers

fn to_json_object(event: Event) -> json.Json {
  json.object([
    #("id", json.string(event.id)),
    #("event_type", json.string(event_type_to_string(event.event_type))),
    #("user_id", encode_optional_int(event.user_id)),
    #("post_id", encode_optional_int(event.post_id)),
    #("method", json.string(event.method)),
    #("path", json.string(event.path)),
    #("status_code", json.int(event.status_code)),
    #("duration_ms", json.int(event.duration_ms)),
    #("timestamp", json.string(event.timestamp)),
  ])
}

fn encode_optional_int(value: option.Option(Int)) -> json.Json {
  case value {
    option.Some(i) -> json.int(i)
    option.None -> json.null()
  }
}

fn identity(x: a) -> a {
  x
}

// Private helper for JSON serialization

fn event_type_to_string(event_type: EventType) -> String {
  case event_type {
    RequestCompleted -> "request_completed"
    PostPublished -> "post_published"
    PostCreated -> "post_created"
    UserCreated -> "user_created"
  }
}
