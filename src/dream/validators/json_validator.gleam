//// JSON validation with helpful error messages
////
//// Validate and decode JSON request bodies with automatic error responses.
////
//// ## Example
////
//// ```gleam
//// import dream/validators/json_validator as validator
//// import gleam/dynamic/decode
////
//// pub type CreateUser {
////   CreateUser(name: String, email: String, age: Int)
//// }
////
//// pub fn create_user(request, ctx, services) {
////   let decoder = decode.into({
////     use name <- decode.parameter
////     use email <- decode.parameter
////     use age <- decode.parameter
////     CreateUser(name:, email:, age:)
////   })
////   |> decode.field("name", decode.string)
////   |> decode.field("email", decode.string)
////   |> decode.field("age", decode.int)
////
////   case validator.validate_or_respond(request.body, decoder) {
////     Ok(user_data) -> {
////       // Create user in database
////       json_response(ok_status(), "User created")
////     }
////     Error(error_response) -> error_response  // Auto-formatted error
////   }
//// }
//// ```

import dream/core/http/statuses.{bad_request_status}
import dream/core/http/transaction.{type Response, json_response}
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

pub fn validate(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, ValidationError) {
  json.parse(body, decode.dynamic)
  |> result.map_error(fn(json_error) {
    ValidationError(
      message: format_json_error(json_error),
      field: option.None,
      expected: option.None,
      found: option.None,
    )
  })
  |> result.try(fn(json_obj) {
    decode.run(json_obj, decoder)
    |> result.map_error(fn(errors) { format_decode_errors(errors) })
  })
}

pub fn error_response(error: ValidationError) -> Response {
  json_response(bad_request_status(), json.to_string(build_error_json(error)))
}

/// Validate JSON body and return either decoded data or error response
/// This is a convenience wrapper around validate that returns Response on error
pub fn validate_or_respond(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, Response) {
  validate(body, decoder)
  |> result.map_error(error_response)
}

fn build_error_json(error: ValidationError) -> json.Json {
  let fields = [
    #("error", json.string(error.message)),
  ]

  let with_field = case error.field {
    option.Some(field) -> [#("field", json.string(field)), ..fields]
    option.None -> fields
  }

  let with_expected = case error.expected {
    option.Some(expected) -> [
      #("expected", json.string(expected)),
      ..with_field
    ]
    option.None -> with_field
  }

  let with_found = case error.found {
    option.Some(found) -> [#("found", json.string(found)), ..with_expected]
    option.None -> with_expected
  }

  json.object(with_found)
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
    Ok(decode.DecodeError(expected, found, path)) -> {
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
    Error(_) -> {
      ValidationError(
        message: "Decode error",
        field: option.None,
        expected: option.None,
        found: option.None,
      )
    }
  }
}
