//// Non-streaming HTTP request functionality
////
//// This module provides non-streaming HTTP request functionality that collects
//// all response chunks and returns the complete response body as a string.
////
//// Use this module when you need the complete response body at once, such as
//// for JSON API responses or small files. For large responses or streaming
//// data, use `dream_http_client/stream` instead.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_http_client/client
//// import dream_http_client/fetch
//// import gleam/http
////
//// let result = client.new
////   |> client.host("api.example.com")
////   |> client.path("/users/123")
////   |> fetch.request()
////
//// case result {
////   Ok(body) -> decode_json(body)
////   Error(msg) -> handle_error(msg)
//// }
//// ```

import dream_http_client/client.{type ClientRequest}
import dream_http_client/stream
import gleam/bit_array
import gleam/bytes_tree
import gleam/result
import gleam/yielder

/// Make a non-streaming HTTP request
///
/// Sends an HTTP request and collects all response chunks, returning the
/// complete response body as a string. This is ideal for:
///
/// - JSON API responses
/// - Small files or documents
/// - Any case where you need the full response before processing
///
/// For large responses (files, streaming data, or AI responses), use
/// `stream.stream_request()` instead to process chunks as they arrive.
///
/// ## Parameters
///
/// - `client_request`: The configured HTTP request
///
/// ## Returns
///
/// - `Ok(String)`: The complete response body as a string
/// - `Error(String)`: An error message if the request failed or body conversion failed
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import dream_http_client/fetch
/// import gleam/http
/// import gleam/json
///
/// let result = client.new
///   |> client.host("api.example.com")
///   |> client.path("/users/123")
///   |> client.add_header("Authorization", "Bearer " <> token)
///   |> fetch.request()
///
/// case result {
///   Ok(body) -> {
///     case json.decode(body, user_decoder) {
///       Ok(user) -> Ok(user)
///       Error(_) -> Error("Invalid JSON response")
///     }
///   }
///   Error(msg) -> Error("Request failed: " <> msg)
/// }
/// ```
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
