//// Parameter validation and extraction utilities
////
//// This module provides safe parameter extraction from HTTP requests,
//// returning Result types with dream.Error instead of crashing on missing or invalid data.
////
//// Use these helpers to validate path parameters and form data in controllers,
//// then pipe the results through your business logic using gleam/result.

import dream/http/error.{type Error, BadRequest}
import dream/http/request.{type Request}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri

/// Require a path parameter as an integer
///
/// Returns a Result with dream.Error if the parameter is missing
/// or cannot be converted to an integer.
///
/// ## Examples
///
/// ```gleam
/// // Using with gleam/result pipeline
/// let result = {
///   use id <- result.try(params.require_int(request, "id"))
///   // ... rest of logic with id : Int
/// }
/// ```
pub fn require_int(req: Request, name: String) -> Result(Int, Error) {
  request.get_int_param(req, name)
  |> result_string_to_error
}

/// Require a path parameter as a string
///
/// Returns a Result with dream.Error if the parameter is missing.
///
/// ## Examples
///
/// ```gleam
/// use name <- result.try(params.require_string(request, "name"))
/// // ... rest of logic with name : String
/// ```
pub fn require_string(req: Request, name: String) -> Result(String, Error) {
  request.get_string_param(req, name)
  |> result_string_to_error
}

/// Require and parse form data from request body
///
/// Returns a Result containing the parsed form data as key-value pairs.
/// Returns an error if the body is empty or invalid.
///
/// ## Examples
///
/// ```gleam
/// use form <- result.try(params.require_form(request))
/// use title <- result.try(params.require_field(form, "title"))
/// ```
pub fn require_form(req: Request) -> Result(List(#(String, String)), Error) {
  case req.body {
    "" -> Error(BadRequest("Request body is empty"))
    body -> Ok(parse_form_body(body))
  }
}

/// Require a field from form data
///
/// Returns an error if the field is missing or empty.
///
/// ## Examples
///
/// ```gleam
/// use form <- result.try(params.require_form(request))
/// use title <- result.try(params.require_field(form, "title"))
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
/// ```gleam
/// use form <- result.try(params.require_form(request))
/// use priority <- result.try(params.require_field_int(form, "priority"))
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
    Ok(i) -> Ok(i)
    Error(_) -> Error(BadRequest("Field '" <> name <> "' must be an integer"))
  }
}

fn result_string_to_error(result: Result(a, String)) -> Result(a, Error) {
  case result {
    Ok(value) -> Ok(value)
    Error(msg) -> Error(BadRequest(msg))
  }
}

/// Extract an optional field from form data
///
/// Returns None if the field is missing or empty, Some(value) otherwise.
/// This never returns an error - use this for truly optional fields.
///
/// ## Examples
///
/// ```gleam
/// let description = params.field_optional(form, "description")
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
    option.Some(kv) -> [kv, ..rest_parsed]
    option.None -> rest_parsed
  }
}

fn parse_form_pair(pair: String) -> option.Option(#(String, String)) {
  case string.split(pair, "=") {
    [key, value] -> {
      let decoded_key = decode_url_component(key)
      let decoded_value = decode_url_component(value)
      option.Some(#(decoded_key, decoded_value))
    }
    [key] -> {
      let decoded_key = decode_url_component(key)
      option.Some(#(decoded_key, ""))
    }
    _ -> option.None
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
