//// Parameter validation and extraction utilities
////
//// This module provides safe parameter extraction from HTTP requests,
//// returning Result types with `dream/http/error.Error` instead of crashing on missing or invalid data.
////
//// Use these helpers to validate path parameters, form data and JSON bodies
//// in controllers, then pipe the results through your business logic using
//// gleam/result.

import dream/http/error.{type Error, BadRequest}
import dream/http/request.{
  type Request, body_as_string, get_int_param, get_string_param,
}
import dream/http/validation.{type ValidationError}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri

/// Require a path parameter as an integer
///
/// Returns a Result with `BadRequest` if the parameter is missing
/// or cannot be converted to an integer.
///
/// ## Examples
///
/// ### Require an integer parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_int.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/int
/// import gleam/result
///
/// pub fn user_path(request: Request) -> Result(String, Error) {
///   // Using with gleam/result pipeline
///   use id <- result.try(params.require_int(request, "id"))
///   // ... rest of logic with id : Int
///   Ok("/users/" <> int.to_string(id))
/// }
/// ```
pub fn require_int(request: Request, name: String) -> Result(Int, Error) {
  get_int_param(request, name)
  |> result_string_to_error
}

/// Require a path parameter as a string
///
/// Returns a Result with `BadRequest` if the parameter is missing.
///
/// ## Examples
///
/// ### Require a string parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_string.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/result
///
/// pub fn greeting(request: Request) -> Result(String, Error) {
///   use name <- result.try(params.require_string(request, "name"))
///   // ... rest of logic with name : String
///   Ok("Hello, " <> name)
/// }
/// ```
pub fn require_string(request: Request, name: String) -> Result(String, Error) {
  get_string_param(request, name)
  |> result_string_to_error
}

/// Require and parse form data from request body
///
/// Returns a Result containing the parsed form data as key-value pairs.
/// Returns `BadRequest("Request body is not text")` when the body is not
/// valid UTF-8, and `BadRequest("Request body is empty")` when the body is
/// empty. A `Stream` body is read to the end first. Each pair is split at its
/// first `=`: the key is the text before it and the value is all the text
/// after it, so `token=a=b` gives `#("token", "a=b")`. A pair with no `=`
/// gives an empty value. An empty pair, from `a=1&&b=2` or a trailing `&`,
/// is skipped.
///
/// ## Examples
///
/// ### Require form data <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_form.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/result
///
/// pub fn task_title(request: Request) -> Result(String, Error) {
///   use form <- result.try(params.require_form(request))
///   use title <- result.try(params.require_field(form, "title"))
///   Ok(title)
/// }
/// ```
pub fn require_form(
  request: Request,
) -> Result(List(#(String, String)), Error) {
  use body <- result.try(require_text_body(request))
  case body {
    "" -> Error(BadRequest("Request body is empty"))
    _ -> Ok(parse_form_body(body))
  }
}

/// Require a JSON body and decode it
///
/// Reads the body as text, parses it as JSON, and runs `decoder` on the
/// result, so a controller gets typed data or one `BadRequest` it can send
/// back. Each step that fails gives `BadRequest` with the reason:
///
/// - The body is not valid UTF-8: `"Request body is not text"`
/// - The body is not JSON: the parse message from `validate_json`, for
///   example `"Unexpected end of JSON input"`
/// - A field is missing or has the wrong type: the decode message from
///   `validate_json`, for example `"Expected Int but found String at priority"`
///
/// A `Stream` body is read to the end first. Use `validation.validate_json`
/// directly when you need the separate `field`, `expected` and `found`
/// values of a `ValidationError`.
///
/// ## Examples
///
/// ### Require a JSON body <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_json.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/dynamic/decode
/// import gleam/result
///
/// pub type NewTask {
///   NewTask(title: String, priority: Int)
/// }
///
/// fn new_task_decoder() -> decode.Decoder(NewTask) {
///   use title <- decode.field("title", decode.string)
///   use priority <- decode.field("priority", decode.int)
///   decode.success(NewTask(title: title, priority: priority))
/// }
///
/// pub fn read_task(request: Request) -> Result(NewTask, Error) {
///   use task <- result.try(params.require_json(request, new_task_decoder()))
///   Ok(task)
/// }
/// ```
pub fn require_json(
  request: Request,
  decoder: decode.Decoder(decoded),
) -> Result(decoded, Error) {
  use body <- result.try(require_text_body(request))
  validation.validate_json(body, decoder)
  |> result.map_error(validation_error_to_bad_request)
}

fn require_text_body(request: Request) -> Result(String, Error) {
  body_as_string(request)
  |> result.replace_error(BadRequest("Request body is not text"))
}

fn validation_error_to_bad_request(validation_error: ValidationError) -> Error {
  BadRequest(validation_error.message)
}

/// Require a field from form data
///
/// Returns an error if the field is missing or empty.
///
/// ## Examples
///
/// ### Require a form field <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_form.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/result
///
/// pub fn task_title(request: Request) -> Result(String, Error) {
///   use form <- result.try(params.require_form(request))
///   use title <- result.try(params.require_field(form, "title"))
///   Ok(title)
/// }
/// ```
pub fn require_field(
  form: List(#(String, String)),
  name: String,
) -> Result(String, Error) {
  case get_form_field(form, name) {
    option.Some("") ->
      Error(BadRequest("Field '" <> name <> "' cannot be empty"))
    option.Some(value) -> Ok(value)
    option.None -> Error(BadRequest("Missing required field: " <> name))
  }
}

/// Require a field from form data as an integer
///
/// Returns an error if the field is missing, empty, or not a valid integer.
///
/// ## Examples
///
/// ### Require an integer field <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_require_field_int.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/error.{type Error}
/// import dream/http/params
/// import dream/http/request.{type Request}
/// import gleam/result
///
/// pub fn task_priority(request: Request) -> Result(Int, Error) {
///   use form <- result.try(params.require_form(request))
///   use priority <- result.try(params.require_field_int(form, "priority"))
///   Ok(priority)
/// }
/// ```
pub fn require_field_int(
  form: List(#(String, String)),
  name: String,
) -> Result(Int, Error) {
  let result = {
    use value <- result.try(require_field(form, name))
    parse_int_field(value, name)
  }
  result
}

fn parse_int_field(value: String, name: String) -> Result(Int, Error) {
  case int.parse(value) {
    Ok(number) -> Ok(number)
    Error(_) -> Error(BadRequest("Field '" <> name <> "' must be an integer"))
  }
}

fn result_string_to_error(result: Result(a, String)) -> Result(a, Error) {
  case result {
    Ok(value) -> Ok(value)
    Error(message) -> Error(BadRequest(message))
  }
}

/// Extract an optional field from form data
///
/// Returns None if the field is missing or empty, Some(value) otherwise.
/// This never returns an error - use this for truly optional fields.
///
/// ## Examples
///
/// ### Read an optional field <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_field_optional.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/params
/// import gleam/option.{type Option}
///
/// pub fn task_description(form: List(#(String, String))) -> Option(String) {
///   let description = params.field_optional(form, "description")
///   description
/// }
/// ```
pub fn field_optional(
  form: List(#(String, String)),
  name: String,
) -> Option(String) {
  case get_form_field(form, name) {
    option.Some("") -> option.None
    option.Some(value) -> option.Some(value)
    option.None -> option.None
  }
}

// Internal form parsing utilities

fn parse_form_body(body: String) -> List(#(String, String)) {
  case body {
    "" -> []
    _ -> parse_form_pairs(string.split(body, "&"))
  }
}

fn parse_form_pairs(pairs: List(String)) -> List(#(String, String)) {
  case pairs {
    [] -> []
    [pair, ..rest] -> {
      let rest_parsed = parse_form_pairs(rest)
      add_parsed_pair(pair, rest_parsed)
    }
  }
}

fn add_parsed_pair(
  pair: String,
  rest_parsed: List(#(String, String)),
) -> List(#(String, String)) {
  case parse_form_pair(pair) {
    option.Some(key_value) -> [key_value, ..rest_parsed]
    option.None -> rest_parsed
  }
}

fn parse_form_pair(pair: String) -> option.Option(#(String, String)) {
  case pair {
    "" -> option.None
    _ -> option.Some(split_form_pair(pair))
  }
}

fn split_form_pair(pair: String) -> #(String, String) {
  case string.split_once(pair, "=") {
    Ok(#(key, value)) -> {
      let decoded_key = decode_url_component(key)
      let decoded_value = decode_url_component(value)
      #(decoded_key, decoded_value)
    }
    Error(Nil) -> {
      let decoded_key = decode_url_component(pair)
      #(decoded_key, "")
    }
  }
}

fn decode_url_component(component: String) -> String {
  // Replace + with space (form encoding convention)
  let with_spaces = string.replace(component, "+", " ")

  // Decode percent-encoded sequences
  case uri.percent_decode(with_spaces) {
    Ok(decoded) -> decoded
    Error(_) -> with_spaces
  }
}

fn get_form_field(
  form_data: List(#(String, String)),
  name: String,
) -> option.Option(String) {
  list.key_find(form_data, name)
  |> option.from_result
}
