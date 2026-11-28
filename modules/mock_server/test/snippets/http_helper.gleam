//// Shared HTTP helpers for documentation snippets.

import gleam/bit_array
import gleam/result

@external(erlang, "http_test_ffi", "make_request_full")
fn make_request_full(url: String) -> Result(#(Int, BitArray), BitArray)

@external(erlang, "http_test_ffi", "make_request_with_method")
fn make_request_with_method(
  url: String,
  method: String,
  body: String,
) -> Result(#(Int, BitArray), BitArray)

fn bits_to_string(bits: BitArray) -> Result(String, String) {
  bit_array.to_string(bits)
  |> result.replace_error("The bytes are not valid UTF-8")
}

fn to_status_and_text(
  response: Result(#(Int, BitArray), BitArray),
) -> Result(#(Int, String), String) {
  case response {
    Ok(#(status, body_bits)) ->
      bits_to_string(body_bits)
      |> result.map(with_status(status, _))
    Error(error_bits) ->
      bits_to_string(error_bits)
      |> result.try(Error)
  }
}

fn with_status(status: Int, body: String) -> #(Int, String) {
  #(status, body)
}

pub fn get(url: String) -> Result(#(Int, String), String) {
  make_request_full(url)
  |> to_status_and_text
}

pub fn post(url: String, body: String) -> Result(#(Int, String), String) {
  make_request_with_method(url, "POST", body)
  |> to_status_and_text
}
