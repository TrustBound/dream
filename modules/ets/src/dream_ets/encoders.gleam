//// Built-in encoders and decoders for common types
////
//// Provides type-safe encoding/decoding for ETS operations.
//// Note: For complex types (like custom types), users should provide
//// their own encoder/decoder functions. Common patterns:
////
//// - Tuples: Store structured data that ETS can pattern match
//// - JSON strings: Store as strings, parse in your code
//// - Custom serialization: Any format that converts to/from Dynamic

import dream_ets/internal
import gleam/dynamic
import gleam/dynamic/decode

/// Encode a string to Dynamic
pub fn string_encoder(s: String) -> dynamic.Dynamic {
  internal.to_dynamic(s)
}

/// Decode a string from Dynamic
pub fn string_decoder() -> decode.Decoder(String) {
  decode.string
}

/// Encode an integer to Dynamic
pub fn int_encoder(i: Int) -> dynamic.Dynamic {
  internal.to_dynamic(i)
}

/// Decode an integer from Dynamic
pub fn int_decoder() -> decode.Decoder(Int) {
  decode.int
}

/// Encode a boolean to Dynamic
pub fn bool_encoder(b: Bool) -> dynamic.Dynamic {
  internal.to_dynamic(b)
}

/// Decode a boolean from Dynamic
pub fn bool_decoder() -> decode.Decoder(Bool) {
  decode.bool
}

/// Encode a float to Dynamic
pub fn float_encoder(f: Float) -> dynamic.Dynamic {
  internal.to_dynamic(f)
}

/// Decode a float from Dynamic
pub fn float_decoder() -> decode.Decoder(Float) {
  decode.float
}
