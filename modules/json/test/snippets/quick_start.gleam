//// README: Quick Start
////
//// Builds a user object with optional fields and a timestamp.

import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}

pub fn user_json(created_at: Timestamp) -> String {
  json.object([
    #("name", json.string("Alice")),
    #("email", encoders.optional_string(option.Some("alice@example.com"))),
    // Encodes as null
    #("age", encoders.optional_int(option.None)),
    #("created_at", encoders.timestamp(option.Some(created_at))),
  ])
  |> json.to_string()
}
