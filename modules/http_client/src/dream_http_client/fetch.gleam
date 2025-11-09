//// Non-streaming HTTP request functionality
////
//// This module provides non-streaming HTTP request functionality that collects
//// all response chunks and returns the complete response body as a string.

import dream_http_client/client.{type ClientRequest}
import dream_http_client/stream
import gleam/bit_array
import gleam/bytes_tree
import gleam/result
import gleam/yielder

/// Make a non-streaming HTTP request
///
/// Takes a ClientRequest and returns the complete response body as a string.
/// This function collects all chunks from the stream and concatenates them.
pub fn request(client_request: ClientRequest) -> Result(String, String) {
  let chunks = stream.stream_request(client_request) |> yielder.to_list

  case chunks {
    [] -> Ok("")
    [single] -> {
      bytes_tree.to_bit_array(single)
      |> bit_array.to_string
      |> result.map_error(fn(_) { "Failed to convert response to string" })
    }
    multiple -> {
      bytes_tree.concat(multiple)
      |> bytes_tree.to_bit_array
      |> bit_array.to_string
      |> result.map_error(fn(_) { "Failed to convert response to string" })
    }
  }
}
