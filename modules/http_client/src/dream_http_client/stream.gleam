//// Streaming HTTP request functionality
////
//// This module provides streaming HTTP request functionality that returns
//// a yielder of response chunks as they arrive. Use this for:
////
//// - Large file downloads
//// - Streaming AI responses
//// - Real-time data feeds
//// - Any case where you want to process data incrementally
////
//// ## Quick Start
////
//// ```gleam
//// import dream_http_client/client
//// import dream_http_client/stream
//// import gleam/yielder
////
//// client.new
////   |> client.host("cdn.example.com")
////   |> client.path("/large-file.zip")
////   |> stream.stream_request()
////   |> yielder.each(fn(chunk) {
////     // Process each chunk as it arrives
////     save_chunk(chunk)
////   })
//// ```
////
//// ## Processing Streams
////
//// The yielder can be consumed with `yielder.each()`, `yielder.to_list()`, or
//// other yielder functions. Each chunk is a `BytesTree` that you can convert
//// to a string or process as binary data.

import dream_http_client/client.{type ClientRequest}
import dream_http_client/internal
import gleam/bytes_tree
import gleam/dynamic/decode as d
import gleam/http/request
import gleam/option.{type Option, None, Some}
import gleam/yielder

/// Convert a ClientRequest to a gleam/http/request.Request
///
/// Internal helper function that converts the builder-style ClientRequest
/// to the standard gleam/http Request type.
fn to_http_request(client_request: ClientRequest) -> request.Request(String) {
  request.Request(
    method: client_request.method,
    headers: client_request.headers,
    body: client_request.body,
    scheme: client_request.scheme,
    host: client_request.host,
    port: client_request.port,
    path: client_request.path,
    query: client_request.query,
  )
}

/// Create a yielder that streams HTTP response chunks
///
/// Sends an HTTP request and returns a yielder that produces chunks of the
/// response body as they arrive from the server. This allows you to process
/// large responses incrementally without loading the entire response into memory.
///
/// The yielder produces `Next(chunk, new_state)` for each chunk until the stream
/// completes, then produces `Done`.
///
/// ## Parameters
///
/// - `req`: The configured HTTP request
///
/// ## Returns
///
/// A `Yielder` that produces `BytesTree` chunks. Use `yielder.each()` to process
/// chunks, or `yielder.to_list()` to collect all chunks.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import dream_http_client/stream
/// import gleam/yielder
/// import gleam/bytes_tree
///
/// // Stream and process chunks
/// client.new
///   |> client.host("api.example.com")
///   |> client.path("/stream")
///   |> stream.stream_request()
///   |> yielder.each(fn(chunk) {
///     let body = bytes_tree.to_string(chunk)
///     process_chunk(body)
///   })
///
/// // Or collect all chunks
/// let chunks = client.new
///   |> client.host("cdn.example.com")
///   |> client.path("/file.zip")
///   |> stream.stream_request()
///   |> yielder.to_list()
/// ```
pub fn stream_request(
  req: ClientRequest,
) -> yielder.Yielder(bytes_tree.BytesTree) {
  let http_req = to_http_request(req)
  // State: None => not started; Some(owner) => streaming
  yielder.unfold(None, fn(state: Option(d.Dynamic)) {
    case state {
      None -> {
        let request_result = internal.start_httpc_stream(http_req)
        let owner = internal.extract_owner_pid(request_result)
        case internal.receive_next(owner) {
          Ok(bin) -> {
            yielder.Next(bytes_tree.from_bit_array(bin), Some(owner))
          }
          Error(_) -> {
            yielder.Done
          }
        }
      }
      Some(owner) -> {
        case internal.receive_next(owner) {
          Ok(bin) -> {
            yielder.Next(bytes_tree.from_bit_array(bin), Some(owner))
          }
          Error(_) -> {
            yielder.Done
          }
        }
      }
    }
  })
}
