//// Core ETS table type and error types
////
//// Provides the Table type and error handling for ETS operations.

import dream_ets/internal
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

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

pub fn table_ref(table: Table(k, v)) -> internal.EtsTableRef {
  let Table(ref, _, _, _, _, _) = table
  ref
}

pub fn table_name(table: Table(k, v)) -> String {
  let Table(_, name, _, _, _, _) = table
  name
}

pub fn encode_key(table: Table(k, v), key: k) -> dynamic.Dynamic {
  let Table(_, _, encoder, _, _, _) = table
  encoder(key)
}

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

pub fn encode_value(table: Table(k, v), value: v) -> dynamic.Dynamic {
  let Table(_, _, _, _, encoder, _) = table
  encoder(value)
}

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

/// Create a new Table instance (internal use only)
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
