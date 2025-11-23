//// JSON validation with structured error messages
////
//// Validate and decode JSON request bodies with detailed error information.
//// Validation is kept separate from response building - controllers
//// decide how to handle validation errors.
////
//// ## Quick Example
////
//// ```gleam
//// import dream/http/validation
//// import gleam/dynamic/decode
////
//// pub type CreateUser {
////   CreateUser(name: String, email: String, age: Int)
//// }
////
//// let user_decoder = {
////   use name <- decode.field("name", decode.string)
////   use email <- decode.field("email", decode.string)
////   use age <- decode.field("age", decode.int)
////   decode.success(CreateUser(name, email, age))
//// }
////
//// pub fn create(request, context, services) {
////   let validation_result = validation.validate_json(request.body, user_decoder)
////   
////   case validation_result {
////     Ok(user) -> create_user(services.db, user)
////     Error(err) -> create_validation_error_response(err)
////   }
//// }
//// 
//// fn create_validation_error_response(err: ValidationError) -> Response {
////   response.json_response(status.bad_request, error_json(err.message))
//// }
//// ```
////
//// ## Error Handling
////
//// ValidationError provides detailed information about what went wrong:
//// - `message`: Human-readable error message
//// - `field`: The JSON field that failed (if applicable)
//// - `expected`: What type was expected
//// - `found`: What type was actually found

import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

/// Validation error with field-level details
///
/// Provides detailed information about JSON validation failures,
/// including the specific field that failed and what was expected vs. found.
///
/// ## Fields
///
/// - `message`: Complete error message suitable for logging or user display
/// - `field`: The JSON path to the field that failed (e.g., "user.email")
/// - `expected`: The expected type (e.g., "String", "Int")
/// - `found`: The actual type found (e.g., "Null", "Bool")
///
/// ## Example
///
/// ```gleam
/// import dream/http/validation.{ValidationError}
/// import gleam/option
///
/// // Example error when expecting string but got number
/// ValidationError(
///   message: "Expected String but found Int at user.email",
///   field: option.Some("user.email"),
///   expected: option.Some("String"),
///   found: option.Some("Int")
/// )
/// ```
pub type ValidationError {
  ValidationError(
    message: String,
    field: option.Option(String),
    expected: option.Option(String),
    found: option.Option(String),
  )
}

/// Validate and decode JSON request body
///
/// Parses JSON string and decodes it using the provided decoder.
/// Returns the decoded data or a detailed validation error.
///
/// This function is generic over the return type - use `gleam/dynamic/decode`
/// to define decoders for your types.
///
/// ## Example
///
/// ```gleam
/// import dream/http/response.{json_response}
/// import dream/http/status.{bad_request, created}
/// import dream/http/validation.{validate_json}
/// import gleam/dynamic/decode
/// import gleam/json
///
/// pub type CreatePost {
///   CreatePost(title: String, body: String, published: Bool)
/// }
///
/// let post_decoder = {
///   use title <- decode.field("title", decode.string)
///   use body <- decode.field("body", decode.string)
///   use published <- decode.field("published", decode.bool)
///   decode.success(CreatePost(title, body, published))
/// }
///
/// pub fn create_post(request, context, services) {
///   case validate_json(request.body, post_decoder) {
///     Ok(post) -> {
///       // Valid post data - proceed with business logic
///       let created = insert_post(services.db, post)
///       json_response(created, post_to_json(created))
///     }
///     
///     Error(err) -> {
///       let field_json = format_field_as_json(err.field)
///       let error_json = json.object([
///         #("error", json.string(err.message)),
///         #("field", field_json)
///       ])
///       json_response(bad_request, json.to_string(error_json))
///     }
///   }
/// }
/// ```
///
/// ## Error Cases
///
/// - Invalid JSON syntax: Returns error with parse details
/// - Missing required field: Returns error with field path
/// - Wrong type: Returns error with expected vs. found types
/// - Invalid enum value: Returns error with validation details
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
