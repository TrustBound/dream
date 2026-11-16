//// README: Timestamps
////
//// Encodes an optional timestamp as a string, or as null.

import dream_json/json_encoders as encoders
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}

pub fn audit_json(created_at: Timestamp) -> String {
  json.object([
    #("created_at", encoders.timestamp(option.Some(created_at))),
    // null
    #("deleted_at", encoders.timestamp(option.None)),
  ])
  |> json.to_string()
}
