//// Built-in encoders and decoders for common types
////
//// This module provides pre-built encoder and decoder functions for Gleam's
//// primitive types. These functions handle the conversion between Gleam types
//// and Erlang's dynamic types for ETS storage.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_ets/config
//// import dream_ets/encoders
////
//// // Use convenience functions (recommended)
//// let assert Ok(table) = config.new("cache")
////   |> config.key_string()
////   |> config.value_string()
////   |> config.create()
////
//// // Or use encoders directly for custom configuration
//// let assert Ok(table) = config.new("scores")
////   |> config.key(encoders.string_encoder, encoders.string_decoder())
////   |> config.value(encoders.int_encoder, encoders.int_decoder())
////   |> config.create()
//// ```
////
//// ## Built-in Types
////
//// This module provides encoders/decoders for:
////
//// - `String` - Text data
//// - `Int` - Integer numbers
//// - `Float` - Floating-point numbers
//// - `Bool` - Boolean values
////
//// ## Custom Types
////
//// For complex or custom types, you'll need to write your own encoders/decoders.
//// Common patterns:
////
//// ### JSON Encoding
////
//// ```gleam
//// import gleam/json
//// import gleam/dynamic
//// import gleam/result
////
//// pub type User {
////   User(name: String, age: Int)
//// }
////
//// fn encode_user(user: User) -> dynamic.Dynamic {
////   json.object([
////     #("name", json.string(user.name)),
////     #("age", json.int(user.age)),
////   ])
////   |> json.to_string
////   |> dynamic.from
//// }
////
//// fn decode_user() -> decode.Decoder(User) {
////   use json_str <- decode.string
////   use obj <- decode.then(json.decode(json_str, decode.dynamic))
////   decode.decode2(
////     User,
////     decode.field("name", decode.string),
////     decode.field("age", decode.int),
////   )(obj)
//// }
//// ```
////
//// ### Tuple Encoding
////
//// ```gleam
//// import gleam/dynamic
////
//// pub type Point {
////   Point(x: Int, y: Int)
//// }
////
//// fn encode_point(p: Point) -> dynamic.Dynamic {
////   dynamic.from(#(p.x, p.y))
//// }
////
//// fn decode_point() -> decode.Decoder(Point) {
////   decode.decode2(
////     Point,
////     decode.element(0, decode.int),
////     decode.element(1, decode.int),
////   )
//// }
//// ```

import dream_ets/internal
import gleam/dynamic
import gleam/dynamic/decode

/// Encode a string to Dynamic
///
/// Converts a Gleam `String` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `s`: The string to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the string.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// let assert Ok(table) = config.new("cache")
///   |> config.key(encoders.string_encoder, encoders.string_decoder())
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `string_decoder()` - Decode strings from storage
/// - `config.key_string()` - Convenience function for string keys
pub fn string_encoder(s: String) -> dynamic.Dynamic {
  internal.to_dynamic(s)
}

/// Decode a string from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `String`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `String`.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// let assert Ok(table) = config.new("users")
///   |> config.key_string()
///   |> config.value(encoders.string_encoder, encoders.string_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `string_encoder()` - Encode strings for storage
/// - `config.value_string()` - Convenience function for string values
pub fn string_decoder() -> decode.Decoder(String) {
  decode.string
}

/// Encode an integer to Dynamic
///
/// Converts a Gleam `Int` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `i`: The integer to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the integer.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// // Counter table with int values
/// let assert Ok(counter) = config.new("counts")
///   |> config.key_string()
///   |> config.value(encoders.int_encoder, encoders.int_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `int_decoder()` - Decode integers from storage
/// - `config.counter()` - Convenience for counter tables
pub fn int_encoder(i: Int) -> dynamic.Dynamic {
  internal.to_dynamic(i)
}

/// Decode an integer from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Int`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Int`.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// let assert Ok(table) = config.new("scores")
///   |> config.key_string()
///   |> config.value(encoders.int_encoder, encoders.int_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `int_encoder()` - Encode integers for storage
pub fn int_decoder() -> decode.Decoder(Int) {
  decode.int
}

/// Encode a boolean to Dynamic
///
/// Converts a Gleam `Bool` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `b`: The boolean to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the boolean.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// // Feature flags table
/// let assert Ok(flags) = config.new("feature_flags")
///   |> config.key_string()
///   |> config.value(encoders.bool_encoder, encoders.bool_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `bool_decoder()` - Decode booleans from storage
pub fn bool_encoder(b: Bool) -> dynamic.Dynamic {
  internal.to_dynamic(b)
}

/// Decode a boolean from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Bool`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Bool`.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// let assert Ok(flags) = config.new("flags")
///   |> config.key_string()
///   |> config.value(encoders.bool_encoder, encoders.bool_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `bool_encoder()` - Encode booleans for storage
pub fn bool_decoder() -> decode.Decoder(Bool) {
  decode.bool
}

/// Encode a float to Dynamic
///
/// Converts a Gleam `Float` to Erlang's dynamic type for storage in ETS.
///
/// ## Parameters
///
/// - `f`: The float to encode
///
/// ## Returns
///
/// A `Dynamic` value representing the float.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// // Prices table with float values
/// let assert Ok(prices) = config.new("product_prices")
///   |> config.key_string()
///   |> config.value(encoders.float_encoder, encoders.float_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `float_decoder()` - Decode floats from storage
pub fn float_encoder(f: Float) -> dynamic.Dynamic {
  internal.to_dynamic(f)
}

/// Decode a float from Dynamic
///
/// Converts an Erlang dynamic type back to a Gleam `Float`.
///
/// ## Returns
///
/// A decoder that converts `Dynamic` values to `Float`.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// let assert Ok(metrics) = config.new("latency")
///   |> config.key_string()
///   |> config.value(encoders.float_encoder, encoders.float_decoder())
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `float_encoder()` - Encode floats for storage
pub fn float_decoder() -> decode.Decoder(Float) {
  decode.float
}
