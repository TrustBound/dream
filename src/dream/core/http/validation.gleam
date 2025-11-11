//// JSON validation with structured error messages
////
//// Validate and decode JSON request bodies.
//// Validation is kept separate from response building - controllers
//// decide how to handle validation errors.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

/// Validation error with field-level details
pub type ValidationError {
  ValidationError(
    message: String,
    field: option.Option(String),
    expected: option.Option(String),
    found: option.Option(String),
  )
}

/// Validate JSON body and decode into a type
/// 
/// Returns Ok(decoded_data) or Error(validation_error).
/// Controllers decide how to handle errors and build responses.
pub fn validate_json(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, ValidationError) {
  json.parse(body, decode.dynamic)
  |> result.map_error(json_error_to_validation)
  |> result.try(decode_with_decoder(_, decoder))
}

fn json_error_to_validation(json_error: json.DecodeError) -> ValidationError {
  ValidationError(
    message: format_json_error(json_error),
    field: option.None,
    expected: option.None,
    found: option.None,
  )
}

fn decode_with_decoder(
  json_obj: dynamic.Dynamic,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, ValidationError) {
  decode.run(json_obj, decoder)
  |> result.map_error(format_decode_errors)
}

fn format_json_error(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "Unexpected end of JSON input"
    json.UnexpectedByte(msg) -> "Unexpected byte: " <> msg
    json.UnexpectedSequence(msg) -> "Unexpected sequence: " <> msg
    json.UnableToDecode(errors) ->
      "Unable to decode: " <> string.inspect(errors)
  }
}

fn format_decode_errors(errors: List(decode.DecodeError)) -> ValidationError {
  case list.first(errors) {
    Ok(error) -> format_single_decode_error(error)
    Error(_) -> create_generic_error()
  }
}

fn format_single_decode_error(error: decode.DecodeError) -> ValidationError {
  let decode.DecodeError(expected, found, path) = error
  let field_path = string.join(path, ".")

  ValidationError(
    message: "Expected "
      <> expected
      <> " but found "
      <> found
      <> " at "
      <> field_path,
    field: option.Some(field_path),
    expected: option.Some(expected),
    found: option.Some(found),
  )
}

fn create_generic_error() -> ValidationError {
  ValidationError(
    message: "Decode error",
    field: option.None,
    expected: option.None,
    found: option.None,
  )
}

