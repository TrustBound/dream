//// Streaming HTTP request functionality
////
//// This module provides streaming HTTP request functionality that returns
//// a yielder of response chunks as they arrive.

import dream/utilities/http/client.{type ClientRequest}
import dream/utilities/http/client/internal
import gleam/bytes_tree
import gleam/dynamic/decode as d
import gleam/http/request
import gleam/option.{type Option, None, Some}
import gleam/yielder

/// Convert a ClientRequest to a gleam/http/request.Request
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
/// Takes a ClientRequest and returns a yielder that produces chunks of the response
/// body as they arrive. The yielder will produce `Next` values with each chunk until
/// the stream completes, at which point it produces `Done`.
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
