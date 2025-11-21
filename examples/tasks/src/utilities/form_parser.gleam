//// Form data parsing utilities
////
//// Parse URL-encoded form data from HTTP request bodies
////
//// Properly decodes URL-encoded values using gleam/uri

import gleam/int
import gleam/option
import gleam/string
import gleam/uri

/// Parse URL-encoded form data from request body
/// Returns a list of key-value pairs
pub fn parse_form_body(body: String) -> List(#(String, String)) {
  case body {
    "" -> []
    _ -> parse_form_pairs(string.split(body, "&"))
  }
}

fn parse_form_pairs(pairs: List(String)) -> List(#(String, String)) {
  case pairs {
    [] -> []
    [pair, ..rest] -> {
      case parse_form_pair(pair) {
        option.Some(kv) -> [kv, ..parse_form_pairs(rest)]
        option.None -> parse_form_pairs(rest)
      }
    }
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

/// Decode a URL-encoded component (key or value)
/// 
/// Handles percent-encoded sequences (e.g., %20, %26) and plus signs (+ → space)
/// Falls back to original string if decoding fails
fn decode_url_component(component: String) -> String {
  // Replace + with space (form encoding convention)
  let with_spaces = string.replace(component, "+", " ")

  // Decode percent-encoded sequences
  case uri.percent_decode(with_spaces) {
    Ok(decoded) -> decoded
    Error(_) -> with_spaces
  }
}

/// Get a form field value by name
pub fn get_form_field(
  form_data: List(#(String, String)),
  name: String,
) -> option.Option(String) {
  case form_data {
    [] -> option.None
    [#(key, value), ..rest] ->
      case key == name {
        True -> option.Some(value)
        False -> get_form_field(rest, name)
      }
  }
}

/// Get a form field as an integer
pub fn get_form_field_int(
  form_data: List(#(String, String)),
  name: String,
) -> option.Option(Int) {
  get_form_field(form_data, name)
  |> option.then(fn(value) {
    case int.parse(value) {
      Ok(int_val) -> option.Some(int_val)
      Error(_) -> option.None
    }
  })
}

/// Get a form field as an optional string (empty string becomes None)
pub fn get_form_field_optional(
  form_data: List(#(String, String)),
  name: String,
) -> option.Option(String) {
  case get_form_field(form_data, name) {
    option.Some("") -> option.None
    option.Some(value) -> option.Some(value)
    option.None -> option.None
  }
}
