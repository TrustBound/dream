//// JSON validation with structured error messages
////
//// Guide: [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html).
////
//// Validate and decode JSON request bodies with detailed error information.
//// Validation is kept separate from response building - controllers
//// decide how to handle validation errors.
////
//// ## Quick Example
////
//// ### Validate a JSON body <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_validation_module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/request.{type Request, body_as_string}
//// import dream/http/response.{type Response}
//// import dream/http/status
//// import dream/http/validation.{type ValidationError}
//// import gleam/dynamic/decode
//// import gleam/json
//// import gleam/list
////
//// pub type CreateUser {
////   CreateUser(name: String, email: String, age: Int)
//// }
////
//// fn user_decoder() -> decode.Decoder(CreateUser) {
////   use name <- decode.field("name", decode.string)
////   use email <- decode.field("email", decode.string)
////   use age <- decode.field("age", decode.int)
////   decode.success(CreateUser(name, email, age))
//// }
////
//// pub fn create(request: Request, _context, _services) -> Response {
////   case body_as_string(request) {
////     Ok(body) -> create_from_json(body)
////     Error(Nil) ->
////       response.json_response(
////         status.bad_request,
////         error_json("Request body is not text"),
////       )
////   }
//// }
////
//// fn create_from_json(body: String) -> Response {
////   let validation_result = validation.validate_json(body, user_decoder())
////
////   case validation_result {
////     Ok(user) -> response.json_response(status.created, user_to_json(user))
////     Error(validation_errors) ->
////       create_validation_error_response(validation_errors)
////   }
//// }
////
//// // One message for each field that failed
//// fn create_validation_error_response(
////   validation_errors: List(ValidationError),
//// ) -> Response {
////   let messages = list.map(validation_errors, error_message)
////   response.json_response(
////     status.bad_request,
////     json.to_string(
////       json.object([#("errors", json.array(messages, json.string))]),
////     ),
////   )
//// }
////
//// fn error_message(validation_error: ValidationError) -> String {
////   validation_error.message
//// }
////
//// fn user_to_json(user: CreateUser) -> String {
////   json.object([
////     #("name", json.string(user.name)),
////     #("email", json.string(user.email)),
////     #("age", json.int(user.age)),
////   ])
////   |> json.to_string
//// }
////
//// fn error_json(message: String) -> String {
////   json.to_string(json.object([#("error", json.string(message))]))
//// }
//// ```
////
//// ## Error Handling
////
//// `validate_json` gives a list with one `ValidationError` for each field
//// that failed, in the order of the decoder. Each one provides detailed
//// information about what went wrong:
//// - `message`: Human-readable error message
//// - `field`: The JSON field that failed (if applicable)
//// - `expected`: What type was expected
//// - `found`: What type was actually found
////
//// `validate_json` takes text. A request body can also be `Bytes` or a
//// `Stream`, so read it with `request.body_as_string` first, as the example
//// does. When one `BadRequest` with the message is enough, use
//// `params.require_json`: it reads the body, parses it and decodes it in one
//// call.

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
/// ### A validation error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_validation_error.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/validation.{type ValidationError, ValidationError}
/// import gleam/option
///
/// pub fn email_error() -> ValidationError {
///   // Example error when expecting string but got number
///   ValidationError(
///     message: "Expected String but found Int at user.email",
///     field: option.Some("user.email"),
///     expected: option.Some("String"),
///     found: option.Some("Int"),
///   )
/// }
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
/// Returns the decoded data, or every validation error. A decode failure
/// gives one `ValidationError` for each decode error, in the order of the
/// decoder, so a body with two wrong fields gives two errors. A JSON syntax
/// error gives a list with that one error.
///
/// This function is generic over the return type - use `gleam/dynamic/decode`
/// to define decoders for your types.
///
/// ## Example
///
/// ### Create a post from JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_validate_json.gleam#L1-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request, body_as_string}
/// import dream/http/response.{type Response, json_response}
/// import dream/http/status.{bad_request, created}
/// import dream/http/validation.{type ValidationError, validate_json}
/// import gleam/dynamic/decode
/// import gleam/json
/// import gleam/option.{type Option}
///
/// pub type CreatePost {
///   CreatePost(title: String, body: String, published: Bool)
/// }
///
/// fn post_decoder() -> decode.Decoder(CreatePost) {
///   use title <- decode.field("title", decode.string)
///   use body <- decode.field("body", decode.string)
///   use published <- decode.field("published", decode.bool)
///   decode.success(CreatePost(title, body, published))
/// }
///
/// pub fn create_post(request: Request, _context, _services) -> Response {
///   case body_as_string(request) {
///     Ok(body) -> create_post_from_json(body)
///     Error(Nil) -> json_response(bad_request, not_text_json())
///   }
/// }
///
/// fn create_post_from_json(body: String) -> Response {
///   case validate_json(body, post_decoder()) {
///     Ok(post) -> {
///       // Valid post data - proceed with business logic
///       json_response(created, post_to_json(post))
///     }
///
///     Error(validation_errors) -> {
///       // One object for each field that failed
///       let errors_json =
///         json.object([
///           #("errors", json.array(validation_errors, validation_error_to_json)),
///         ])
///       json_response(bad_request, json.to_string(errors_json))
///     }
///   }
/// }
///
/// fn validation_error_to_json(validation_error: ValidationError) -> json.Json {
///   json.object([
///     #("error", json.string(validation_error.message)),
///     #("field", format_field_as_json(validation_error.field)),
///   ])
/// }
/// ```
///
/// ## Error Cases
///
/// - Invalid JSON syntax: one error with parse details
/// - Missing required field: an error with the field path, for each field
/// - Wrong type: an error with expected vs. found types, for each field
/// - Invalid enum value: an error with validation details
///
/// Guide: [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html).
pub fn validate_json(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, List(ValidationError)) {
  json.parse(body, decoder)
  |> result.map_error(json_error_to_validation)
}

fn json_error_to_validation(
  json_error: json.DecodeError,
) -> List(ValidationError) {
  case json_error {
    json.UnableToDecode(errors) -> list.map(errors, format_single_decode_error)
    json.UnexpectedEndOfInput -> [syntax_error("Unexpected end of JSON input")]
    json.UnexpectedByte(byte) -> [syntax_error("Unexpected byte: " <> byte)]
    json.UnexpectedSequence(sequence) -> [
      syntax_error("Unexpected sequence: " <> sequence),
    ]
  }
}

fn syntax_error(message: String) -> ValidationError {
  ValidationError(
    message: message,
    field: option.None,
    expected: option.None,
    found: option.None,
  )
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
