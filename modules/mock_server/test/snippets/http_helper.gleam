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

fn bits_to_string(bits: BitArray) -> String {
  bit_array.to_string(bits) |> result.unwrap("")
}

pub fn get(url: String) -> Result(#(Int, String), String) {
  case make_request_full(url) {
    Ok(#(status, body_bits)) -> Ok(#(status, bits_to_string(body_bits)))
    Error(err_bits) -> Error(bits_to_string(err_bits))
  }
}

pub fn post(url: String, body: String) -> Result(#(Int, String), String) {
  case make_request_with_method(url, "POST", body) {
    Ok(#(status, body_bits)) -> Ok(#(status, bits_to_string(body_bits)))
    Error(err_bits) -> Error(bits_to_string(err_bits))
  }
}
