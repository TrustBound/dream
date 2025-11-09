//// Event model - OpenSearch repository
////
//// Demonstrates clean pattern for non-SQL data store.
//// No nested cases, no anonymous functions.

import dream_opensearch/client as opensearch
import dream_opensearch/document
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import types/errors.{type DataError, DatabaseError}
import types/event.{
  type Event, type EventType, Event, PostCreated, PostPublished, RequestCompleted,
  UserCreated,
}

/// Log an event to OpenSearch
pub fn log(client: opensearch.Client, event: Event) -> Result(Nil, DataError) {
  document.index(client, "events", event.id, event_to_json(event))
  |> result.map_error(to_data_error)
  |> result.map(ignore_response)
}

/// Get recent events from OpenSearch
pub fn recent(
  client: opensearch.Client,
  limit: Int,
) -> Result(List(Event), DataError) {
  let query = build_recent_query(limit)
  
  document.search(client, "events", query)
  |> result.map_error(to_data_error)
  |> result.try(parse_search_response)
}

// Private helpers - all named functions

fn event_to_json(event: Event) -> String {
  build_event_json_object(event)
  |> json.to_string()
}

fn build_event_json_object(evt: Event) -> json.Json {
  json.object([
    #("event_type", json.string(event_type_to_string(evt.event_type))),
    #("user_id", encode_optional_int(evt.user_id)),
    #("post_id", encode_optional_int(evt.post_id)),
    #("method", json.string(evt.method)),
    #("path", json.string(evt.path)),
    #("status_code", json.int(evt.status_code)),
    #("duration_ms", json.int(evt.duration_ms)),
    #("timestamp", json.string(evt.timestamp)),
  ])
}

fn encode_optional_int(value: option.Option(Int)) -> json.Json {
  case value {
    option.Some(i) -> json.int(i)
    option.None -> json.null()
  }
}

fn build_recent_query(limit: Int) -> String {
  json.object([
    #("size", json.int(limit)),
    #("sort", build_sort_array()),
  ])
  |> json.to_string()
}

fn build_sort_array() -> json.Json {
  json.array([build_timestamp_sort()], identity)
}

fn identity(x: a) -> a {
  x
}

fn build_timestamp_sort() -> json.Json {
  json.object([
    #("timestamp", json.object([#("order", json.string("desc"))])),
  ])
}

fn parse_search_response(response_json: String) -> Result(List(Event), DataError) {
  json.parse(response_json, decode.dynamic)
  |> result.map_error(json_error_to_data_error)
  |> result.try(extract_hits)
}

fn json_error_to_data_error(_: json.DecodeError) -> DataError {
  DatabaseError
}

fn extract_hits(response: dynamic.Dynamic) -> Result(List(Event), DataError) {
  decode.run(response, hits_decoder())
  |> result.map_error(decode_error_to_data_error)
}

fn decode_error_to_data_error(_: List(decode.DecodeError)) -> DataError {
  DatabaseError
}

fn hits_decoder() -> decode.Decoder(List(Event)) {
  use hits <- decode.field("hits", hits_array_decoder())
  decode.success(hits)
}

fn hits_array_decoder() -> decode.Decoder(List(Event)) {
  use hits <- decode.field("hits", decode.list(source_decoder()))
  decode.success(hits)
}

fn source_decoder() -> decode.Decoder(Event) {
  use source <- decode.field("_source", event_decoder())
  decode.success(source)
}

fn event_decoder() -> decode.Decoder(Event) {
  use id <- decode.field("id", decode.optional(decode.string))
  use event_type <- decode.field("event_type", decode.string)
  use user_id <- decode.field("user_id", decode.optional(decode.int))
  use post_id <- decode.field("post_id", decode.optional(decode.int))
  use method <- decode.field("method", decode.string)
  use path <- decode.field("path", decode.string)
  use status_code <- decode.field("status_code", decode.int)
  use duration_ms <- decode.field("duration_ms", decode.int)
  use timestamp <- decode.field("timestamp", decode.string)
  
  decode.success(Event(
    id: option.unwrap(id, ""),
    event_type: event_type_from_string(event_type),
    user_id: user_id,
    post_id: post_id,
    method: method,
    path: path,
    status_code: status_code,
    duration_ms: duration_ms,
    timestamp: timestamp,
  ))
}

fn to_data_error(_: String) -> DataError {
  DatabaseError
}

fn ignore_response(_: String) -> Nil {
  Nil
}

// Private adapter functions for OpenSearch serialization

fn event_type_to_string(event_type: EventType) -> String {
  case event_type {
    RequestCompleted -> "request_completed"
    PostPublished -> "post_published"
    PostCreated -> "post_created"
    UserCreated -> "user_created"
  }
}

fn event_type_from_string(event_type: String) -> EventType {
  case event_type {
    "post_published" -> PostPublished
    "post_created" -> PostCreated
    "user_created" -> UserCreated
    _ -> RequestCompleted
  }
}

