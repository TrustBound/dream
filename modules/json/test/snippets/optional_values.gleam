//// README: Optional Values
////
//// Encodes Some(value) as the JSON value and None as null.

import dream_json/json_encoders as encoders
import gleam/json
import gleam/option

pub fn profile_json() -> String {
  json.object([
    #("name", json.string("Alice")),
    // null
    #("middle_name", encoders.optional_string(option.None)),
    // "Al"
    #("nickname", encoders.optional_string(option.Some("Al"))),
    // 30
    #("age", encoders.optional_int(option.Some(30))),
    // null
    #("score", encoders.optional_float(option.None)),
    // true
    #("is_active", encoders.optional_bool(option.Some(True))),
  ])
  |> json.to_string()
}
