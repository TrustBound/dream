//// Core ETS table type and error types
////
//// This module provides the core `Table` type and error handling for ETS
//// (Erlang Term Storage) operations. ETS provides in-memory key-value storage
//// that's fast, concurrent, and process-safe.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_ets as ets
////
//// // Create a table using the builder
//// let assert Ok(table) = ets.new("my_table")
////   |> ets.key_string()
////   |> ets.value_string()
////   |> ets.create()
////
//// // Or use convenience functions
//// let assert Ok(counter) = ets.new_counter("user_counts")
//// ```
////
//// ## Type Safety
////
//// Tables are parameterized over their key and value types, ensuring type
//// safety at compile time. The encoder/decoder functions handle conversion
//// to/from Erlang's dynamic types for storage.

import dream_ets/internal
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

/// Type-safe ETS table
///
/// Represents an ETS table with type-safe key and value types. The table
/// stores encoder/decoder functions to convert between Gleam types and
/// Erlang's dynamic types for storage.
///
/// Tables are opaque - you cannot construct them directly. Use the builder
/// pattern in `dream_ets/config` or convenience functions in `dream_ets/helpers`
/// to create tables.
///
/// ## Type Parameters
///
/// - `key`: The type of keys stored in the table
/// - `value`: The type of values stored in the table
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// // Create a string-to-string table
/// let assert Ok(table) = ets.new("cache")
///   |> ets.key_string()
///   |> ets.value_string()
///   |> ets.create()
///
/// // Type-safe operations
/// ets.set(table, "user:123", "Alice")  // ✅ Compiles
/// // ets.set(table, 123, "Alice")     // ❌ Type error
/// ```
pub opaque type Table(key, value) {
  Table(
    table_ref: internal.EtsTableRef,
    name: String,
    key_encoder: fn(key) -> dynamic.Dynamic,
    key_decoder: decode.Decoder(key),
    value_encoder: fn(value) -> dynamic.Dynamic,
    value_decoder: decode.Decoder(value),
  )
}

/// ETS operation error types
///
/// Represents errors that can occur during ETS operations. All operations
/// return `Result(_, EtsError)` to force error handling.
///
/// ## Variants
///
/// - `TableNotFound`: The table doesn't exist or was deleted
/// - `TableAlreadyExists`: Attempted to create a table with a name that's already in use
/// - `InvalidKey`: Key encoding/decoding failed or key type is invalid
/// - `InvalidValue`: Value encoding/decoding failed or value type is invalid
/// - `DecodeError(DecodeError)`: Failed to decode a value from storage
/// - `EncodeError(String)`: Failed to encode a value for storage
/// - `OperationFailed(String)`: A general operation failure with a message
/// - `EmptyTable`: Operation requires a non-empty table
/// - `EndOfTable`: Reached the end while iterating
pub type EtsError {
  TableNotFound
  TableAlreadyExists
  InvalidKey
  InvalidValue
  DecodeError(decode.DecodeError)
  EncodeError(String)
  OperationFailed(String)
  EmptyTable
  EndOfTable
}

/// Get the internal table reference
///
/// Returns the underlying EtsTableRef for internal operations. This is
/// primarily used by the operations module and should not be needed in
/// application code.
///
/// ## Parameters
///
/// - `table`: The table to get the reference from
///
/// ## Returns
///
/// The internal table reference.
pub fn table_ref(table: Table(k, v)) -> internal.EtsTableRef {
  let Table(ref, _, _, _, _, _) = table
  ref
}

/// Get the table name
///
/// Returns the name that was used when creating the table. Useful for
/// debugging and logging.
///
/// ## Parameters
///
/// - `table`: The table to get the name from
///
/// ## Returns
///
/// The table name as a string.
pub fn table_name(table: Table(k, v)) -> String {
  let Table(_, name, _, _, _, _) = table
  name
}

/// Encode a key for storage
///
/// Converts a typed key to a dynamic value for storage in ETS. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the key encoder
/// - `key`: The key to encode
///
/// ## Returns
///
/// The encoded key as a dynamic value.
pub fn encode_key(table: Table(k, v), key: k) -> dynamic.Dynamic {
  let Table(_, _, encoder, _, _, _) = table
  encoder(key)
}

/// Decode a key from storage
///
/// Converts a dynamic value from ETS storage back to the typed key. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the key decoder
/// - `dyn`: The dynamic value to decode
///
/// ## Returns
///
/// - `Ok(key)`: Successfully decoded key
/// - `Error(DecodeError)`: Decoding failed
pub fn decode_key(
  table: Table(k, v),
  dyn: dynamic.Dynamic,
) -> Result(k, decode.DecodeError) {
  let Table(_, _, _, decoder, _, _) = table
  decode.run(dyn, decoder)
  |> result.map_error(extract_first_decode_error)
}

fn extract_first_decode_error(
  errors: List(decode.DecodeError),
) -> decode.DecodeError {
  case list.first(errors) {
    Ok(error) -> error
    Error(_) -> decode.DecodeError("key", "decoding failed", [])
  }
}

/// Encode a value for storage
///
/// Converts a typed value to a dynamic value for storage in ETS. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the value encoder
/// - `value`: The value to encode
///
/// ## Returns
///
/// The encoded value as a dynamic value.
pub fn encode_value(table: Table(k, v), value: v) -> dynamic.Dynamic {
  let Table(_, _, _, _, encoder, _) = table
  encoder(value)
}

/// Decode a value from storage
///
/// Converts a dynamic value from ETS storage back to the typed value. This is
/// used internally by operations and typically not needed in application code.
///
/// ## Parameters
///
/// - `table`: The table with the value decoder
/// - `dyn`: The dynamic value to decode
///
/// ## Returns
///
/// - `Ok(value)`: Successfully decoded value
/// - `Error(DecodeError)`: Decoding failed
pub fn decode_value(
  table: Table(k, v),
  dyn: dynamic.Dynamic,
) -> Result(v, decode.DecodeError) {
  let Table(_, _, _, _, _, decoder) = table
  decode.run(dyn, decoder)
  |> result.map_error(extract_first_value_decode_error)
}

fn extract_first_value_decode_error(
  errors: List(decode.DecodeError),
) -> decode.DecodeError {
  case list.first(errors) {
    Ok(error) -> error
    Error(_) -> decode.DecodeError("value", "decoding failed", [])
  }
}

/// Create a new Table instance
///
/// Constructs a new Table from its components. This is used internally by
/// the builder pattern and should not be called directly from application code.
///
/// ## Parameters
///
/// - `table_ref`: The internal ETS table reference
/// - `name`: The table name
/// - `key_encoder`: Function to encode keys
/// - `key_decoder`: Decoder for keys
/// - `value_encoder`: Function to encode values
/// - `value_decoder`: Decoder for values
///
/// ## Returns
///
/// A new Table instance with the provided configuration.
pub fn new_table(
  table_ref: internal.EtsTableRef,
  name: String,
  key_encoder: fn(k) -> dynamic.Dynamic,
  key_decoder: decode.Decoder(k),
  value_encoder: fn(v) -> dynamic.Dynamic,
  value_decoder: decode.Decoder(v),
) -> Table(k, v) {
  Table(
    table_ref: table_ref,
    name: name,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}
