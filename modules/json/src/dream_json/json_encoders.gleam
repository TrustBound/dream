//// Common JSON encoding utilities for Gleam types
////
//// This module provides convenience functions for encoding common Gleam types
//// to JSON, handling optional values and timestamps. These functions handle
//// the common pattern of encoding `Option` types as either their value or `null`.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_json/json_encoders as encoders
//// import gleam/json
//// import gleam/option
////
//// let user_json = json.object([
////   #("name", json.string("Alice")),
////   #("email", encoders.optional_string(user.email)),
////   #("age", encoders.optional_int(user.age)),
////   #("created_at", encoders.timestamp(user.created_at)),
//// ])
//// ```
////
//// ## Optional Values
////
//// All `optional_*` functions convert `Option` types to JSON, encoding
//// `Some(value)` as the JSON value and `None` as `null`. This is the standard
//// pattern for optional fields in JSON APIs.

import gleam/json
import gleam/option
import gleam/string
import gleam/time/timestamp

/// Encode an optional string value to JSON
///
/// Converts an `Option(String)` to JSON, encoding `Some(text)` as a JSON string
/// and `None` as `null`. This is the standard pattern for optional string fields
/// in JSON responses.
///
/// ## Parameters
///
/// - `value`: The optional string value to encode
///
/// ## Returns
///
/// - `json.Json`: A JSON string if `Some`, or `null` if `None`
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/json
/// import gleam/option
///
/// let json = json.object([
///   #("name", json.string("Alice")),
///   #("middle_name", encoders.optional_string(option.None)),
///   #("nickname", encoders.optional_string(option.Some("Al"))),
/// ])
/// // Results in: {"name": "Alice", "middle_name": null, "nickname": "Al"}
/// ```
pub fn optional_string(value: option.Option(String)) -> json.Json {
  case value {
    option.Some(text) -> json.string(text)
    option.None -> json.null()
  }
}

/// Encode an optional integer to JSON
///
/// Converts an `Option(Int)` to JSON, encoding `Some(num)` as a JSON number
/// and `None` as `null`. Use this for optional numeric fields like counts,
/// IDs, or ages.
///
/// ## Parameters
///
/// - `value`: The optional integer value to encode
///
/// ## Returns
///
/// - `json.Json`: A JSON number if `Some`, or `null` if `None`
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/json
/// import gleam/option
///
/// let json = json.object([
///   #("user_id", json.int(123)),
///   #("parent_id", encoders.optional_int(option.None)),
///   #("age", encoders.optional_int(option.Some(30))),
/// ])
/// ```
pub fn optional_int(value: option.Option(Int)) -> json.Json {
  case value {
    option.Some(num) -> json.int(num)
    option.None -> json.null()
  }
}

/// Encode a timestamp to JSON string
///
/// Converts an `Option(Timestamp)` to JSON, encoding `Some(timestamp)` as an
/// ISO 8601 string representation and `None` as `null`. Timestamps are
/// serialized using their string representation.
///
/// ## Parameters
///
/// - `ts`: The optional timestamp value to encode
///
/// ## Returns
///
/// - `json.Json`: A JSON string if `Some`, or `null` if `None`
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/json
/// import gleam/time/timestamp
///
/// let now = timestamp.now()
/// let json = json.object([
///   #("created_at", encoders.timestamp(option.Some(now))),
///   #("deleted_at", encoders.timestamp(option.None)),
/// ])
/// ```
pub fn timestamp(ts: option.Option(timestamp.Timestamp)) -> json.Json {
  case ts {
    option.Some(t) -> json.string(timestamp_to_string(t))
    option.None -> json.null()
  }
}

/// Convert timestamp to string for serialization
///
/// Converts a `Timestamp` to its string representation. This is used internally
/// by `timestamp()` but can also be used directly when you have a non-optional
/// timestamp.
///
/// ## Parameters
///
/// - `ts`: The timestamp to convert
///
/// ## Returns
///
/// - `String`: The string representation of the timestamp
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/time/timestamp
///
/// let now = timestamp.now()
/// let timestamp_str = encoders.timestamp_to_string(now)
/// ```
pub fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  string.inspect(ts)
}

/// Encode an optional float to JSON
///
/// Converts an `Option(Float)` to JSON, encoding `Some(num)` as a JSON number
/// and `None` as `null`. Use this for optional floating-point values like
/// prices, percentages, or measurements.
///
/// ## Parameters
///
/// - `value`: The optional float value to encode
///
/// ## Returns
///
/// - `json.Json`: A JSON number if `Some`, or `null` if `None`
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/json
/// import gleam/option
///
/// let json = json.object([
///   #("price", encoders.optional_float(option.Some(19.99))),
///   #("discount", encoders.optional_float(option.None)),
/// ])
/// ```
pub fn optional_float(value: option.Option(Float)) -> json.Json {
  case value {
    option.Some(num) -> json.float(num)
    option.None -> json.null()
  }
}

/// Encode an optional boolean to JSON
///
/// Converts an `Option(Bool)` to JSON, encoding `Some(val)` as a JSON boolean
/// and `None` as `null`. Use this for optional boolean flags or settings.
///
/// ## Parameters
///
/// - `value`: The optional boolean value to encode
///
/// ## Returns
///
/// - `json.Json`: A JSON boolean if `Some`, or `null` if `None`
///
/// ## Example
///
/// ```gleam
/// import dream_json/json_encoders as encoders
/// import gleam/json
/// import gleam/option
///
/// let json = json.object([
///   #("is_active", encoders.optional_bool(option.Some(True))),
///   #("is_verified", encoders.optional_bool(option.None)),
/// ])
/// ```
pub fn optional_bool(value: option.Option(Bool)) -> json.Json {
  case value {
    option.Some(val) -> json.bool(val)
    option.None -> json.null()
  }
}
