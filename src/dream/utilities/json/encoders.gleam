//// Common JSON encoding utilities for Gleam types
////
//// This module provides convenience functions for encoding common Gleam types
//// to JSON, handling optional values and timestamps.

import gleam/json
import gleam/option
import gleam/string
import gleam/time/timestamp

/// Encode an optional string value to JSON (null if None)
pub fn optional_string(value: option.Option(String)) -> json.Json {
  case value {
    option.Some(text) -> json.string(text)
    option.None -> json.null()
  }
}

/// Encode an optional integer to JSON (null if None)
pub fn optional_int(value: option.Option(Int)) -> json.Json {
  case value {
    option.Some(num) -> json.int(num)
    option.None -> json.null()
  }
}

/// Encode a timestamp to JSON string (null if None)
pub fn timestamp(ts: option.Option(timestamp.Timestamp)) -> json.Json {
  case ts {
    option.Some(t) -> json.string(string.inspect(t))
    option.None -> json.null()
  }
}

/// Encode an optional float to JSON (null if None)
pub fn optional_float(value: option.Option(Float)) -> json.Json {
  case value {
    option.Some(num) -> json.float(num)
    option.None -> json.null()
  }
}

/// Encode an optional boolean to JSON (null if None)
pub fn optional_bool(value: option.Option(Bool)) -> json.Json {
  case value {
    option.Some(val) -> json.bool(val)
    option.None -> json.null()
  }
}
