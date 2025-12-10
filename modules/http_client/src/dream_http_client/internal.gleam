//// Internal utilities for HTTP client
////
//// This module provides internal utilities for the HTTP client, including
//// Erlang externals and low-level stream handling. These functions are used
//// internally by the public API and should not be used directly by application
//// code.
////
//// This is an internal module. Use `dream_http_client/client`,
//// `dream_http_client/fetch`, and `dream_http_client/stream` instead.

import gleam/dynamic/decode as d
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import gleam/string

// Erlang externals for streaming HTTP requests
@external(erlang, "dream_httpc_shim", "request_stream")
fn request_stream(
  method: atom.Atom,
  url: String,
  headers: List(#(String, String)),
  body: BitArray,
  receiver: process.Pid,
  timeout_ms: Int,
) -> d.Dynamic

@external(erlang, "dream_httpc_shim", "fetch_next")
fn fetch_next(owner: d.Dynamic, timeout_ms: Int) -> d.Dynamic

/// Convert an HTTP method to an Erlang atom
///
/// Converts a Gleam HTTP method type to an Erlang atom for use with the
/// Erlang httpc library. This is an internal function used by the streaming
/// request implementation.
///
/// ## Parameters
///
/// - `method`: The HTTP method to convert
///
/// ## Returns
///
/// An Erlang atom representing the HTTP method (e.g., `"get"`, `"post"`).
pub fn atomize_method(method: http.Method) -> atom.Atom {
  case method {
    http.Get -> atom.create("get")
    http.Post -> atom.create("post")
    http.Put -> atom.create("put")
    http.Delete -> atom.create("delete")
    http.Patch -> atom.create("patch")
    http.Head -> atom.create("head")
    http.Options -> atom.create("options")
    http.Trace -> atom.create("trace")
    http.Connect -> atom.create("connect")
    http.Other(method_string) -> atom.create(string.lowercase(method_string))
  }
}

/// Start an HTTP streaming request
///
/// Initiates a streaming HTTP request using Erlang's httpc library. This
/// function constructs the URL, converts the method to an atom, and starts
/// the streaming process. Returns a dynamic value containing the owner PID
/// that can be used to receive chunks.
///
/// ## Parameters
///
/// - `request`: The HTTP request to send
/// - `timeout_ms`: Timeout in milliseconds for the request
///
/// ## Returns
///
/// A dynamic value containing the owner PID in the format `{ok, OwnerPid}`.
/// Use `extract_owner_pid()` to get the PID for receiving chunks.
pub fn start_httpc_stream(
  request: Request(String),
  timeout_ms: Int,
) -> d.Dynamic {
  let port_string = case request.port {
    option.Some(port) -> ":" <> int.to_string(port)
    option.None -> ""
  }
  let url =
    http.scheme_to_string(request.scheme)
    <> "://"
    <> request.host
    <> port_string
    <> request.path
  let method_atom = atomize_method(request.method)
  let body = <<request.body:utf8>>
  let receiver = process.self()
  request_stream(method_atom, url, request.headers, body, receiver, timeout_ms)
}

/// Extract the owner PID from the request result
///
/// Extracts the owner process ID from the result returned by `start_httpc_stream()`.
/// The owner PID is used to receive response chunks from the streaming request.
///
/// ## Parameters
///
/// - `request_result`: The dynamic result from `start_httpc_stream()`, which is
///   always `{ok, OwnerPid}` (errors are detected asynchronously)
///
/// ## Returns
///
/// The owner PID as a dynamic value. If the HTTP request fails, the owner process
/// will exit and `receive_next()` will return an error.
pub fn extract_owner_pid(request_result: d.Dynamic) -> d.Dynamic {
  // Extract element [1] from {ok, OwnerPid} tuple
  // This should always succeed since request_stream always returns {ok, Pid}
  case d.run(request_result, d.at([1], d.dynamic)) {
    Ok(pid) -> pid
    Error(decode_errors) -> {
      // Defensive: This should never happen since request_stream always returns {ok, Pid}
      // If it does, log it so we know something changed in the shim
      let error_details = string.inspect(decode_errors)
      io.println_error(
        "WARNING: Failed to extract owner PID - this should not happen. Error: "
        <> error_details,
      )
      // Return original value - error will surface when receive_next tries to use it
      request_result
    }
  }
}

/// Receive the next chunk from the stream
///
/// Receives the next chunk of data from an active streaming HTTP request.
/// Returns `Ok(BitArray)` when a chunk is available, or `Error(String)` when
/// the stream has finished or an error occurred.
///
/// ## Parameters
///
/// - `owner`: The owner PID from `extract_owner_pid()`
/// - `timeout_ms`: Timeout in milliseconds for receiving the next chunk
///
/// ## Returns
///
/// - `Ok(Some(BitArray))`: The next chunk of response data
/// - `Ok(None)`: Stream finished normally (no more data)
/// - `Error(String)`: Error occurred with reason
pub fn receive_next(
  owner: d.Dynamic,
  timeout_ms: Int,
) -> Result(option.Option(BitArray), String) {
  let resp = fetch_next(owner, timeout_ms)
  let tag =
    d.run(resp, d.at([0], d.dynamic))
    |> result.try(convert_to_atom)
    |> result.unwrap(atom.create(""))
    |> atom.to_string
  case tag {
    "chunk" -> {
      let bin = d.run(resp, d.at([1], d.bit_array)) |> result.unwrap(<<>>)
      Ok(option.Some(bin))
    }
    "finished" -> Ok(option.None)
    "error" -> {
      let reason =
        d.run(resp, d.at([1], d.string))
        |> result.unwrap("Unknown stream error")
      Error(reason)
    }
    _ -> Error("Unexpected stream message tag: " <> tag)
  }
}

fn convert_to_atom(dyn: d.Dynamic) -> Result(atom.Atom, e) {
  Ok(atom.cast_from_dynamic(dyn))
}

// ============================================================================
// Message-Based Streaming FFI
// ============================================================================

/// Start a message-based streaming HTTP request
///
/// Low-level FFI function that initiates a streaming HTTP request using Erlang's
/// `httpc` library. Messages are sent directly to the specified process mailbox
/// without buffering or an intermediate owner process.
///
/// **Note:** This is an internal function used by the public API. Most callers
/// should use `client.stream_messages()` instead.
///
/// ## Parameters
///
/// - `method`: HTTP method as an Erlang atom (e.g., `atom.create("get")`)
/// - `url`: Full request URL (scheme://host:port/path?query)
/// - `headers`: List of HTTP header name-value pairs
/// - `body`: Request body as a `BitArray`
/// - `receiver`: Process ID that will receive stream messages
/// - `timeout_ms`: Request timeout in milliseconds
///
/// ## Returns
///
/// A dynamic value containing either:
/// - `{ok, RequestId}` - Stream started successfully
/// - `{error, Reason}` - Failed to start stream
///
/// ## Notes
///
/// - This function is used internally by `client.stream_messages()`
/// - Messages arrive as Erlang tuples that must be decoded
/// - Use `decode_stream_message_for_selector()` for selector integration
@external(erlang, "dream_httpc_shim", "request_stream_messages")
pub fn start_stream_messages(
  method: atom.Atom,
  url: String,
  headers: List(#(String, String)),
  body: BitArray,
  receiver: process.Pid,
  timeout_ms: Int,
) -> d.Dynamic

/// Cancel a streaming request
///
/// Low-level FFI function that cancels an active streaming HTTP request using
/// the httpc request ID.
///
/// **Note:** This is an internal function used by the public API. Most callers
/// should use `client.cancel_stream()` instead.
///
/// ## Parameters
///
/// - `request_id`: The httpc request ID as a dynamic value
///
/// ## Notes
///
/// - This function is used internally by `client.cancel_stream()`
/// - After cancellation, no more messages will be sent to the receiver process
/// - Safe to call multiple times on the same request ID
@external(erlang, "dream_httpc_shim", "cancel_stream")
pub fn cancel_stream_internal(request_id: d.Dynamic) -> Nil

/// Cancel a streaming request by string ID
///
/// Low-level FFI function that cancels an active streaming HTTP request using
/// the string representation of the request ID.
///
/// **Note:** This is an internal function used by the public API. Most callers
/// should use `client.cancel_stream()` instead.
///
/// ## Parameters
///
/// - `request_id_string`: The request ID as a string (from `RequestId.id`)
///
/// ## Notes
///
/// - This function is used internally by `client.cancel_stream()`
/// - Converts the string ID to the appropriate format for httpc
/// - After cancellation, no more messages will be sent to the receiver process
@external(erlang, "dream_httpc_shim", "cancel_stream_by_string")
pub fn cancel_stream_by_string(request_id_string: String) -> Nil

/// Receive the next stream message with timeout
///
/// Low-level FFI function that blocks waiting for an httpc stream message from
/// the process mailbox and returns a normalized tuple. This is used for direct
/// message receiving without selector integration.
///
/// **Note:** This is an internal function. Most callers should use OTP selectors
/// with `client.select_stream_messages()` instead.
///
/// ## Parameters
///
/// - `timeout_ms`: Timeout in milliseconds (0 for non-blocking, -1 for infinite)
///
/// ## Returns
///
/// A dynamic value containing a normalized stream message tuple:
/// - `{Tag, RequestId, Data}` where Tag is an atom ("stream_start", "chunk", etc.)
///
/// ## Notes
///
/// - This function is used internally for non-selector message handling
/// - Messages are normalized by the Erlang shim before being returned
/// - Use `decode_stream_message_for_selector()` for selector integration
@external(erlang, "dream_httpc_shim", "receive_stream_message")
pub fn receive_stream_message(timeout_ms: Int) -> d.Dynamic

/// Decode stream message for selector integration
///
/// Low-level FFI function that processes raw httpc messages from OTP selectors.
/// The Erlang shim handles pattern matching, normalizes charlists to binaries,
/// and returns a clean tuple format that Gleam can easily decode.
///
/// **Note:** This is an internal function used by `client.select_stream_messages()`.
/// Most callers should use the public selector API instead.
///
/// ## Parameters
///
/// - `message`: The inner tuple from `{http, InnerTuple}` extracted by the selector
///
/// ## Returns
///
/// A clean `{Tag, RequestId, Data}` tuple where:
/// - `Tag` is an atom ("stream_start", "chunk", "stream_end", "stream_error")
/// - `RequestId` is a string identifier
/// - `Data` varies by message type (headers, chunk data, error reason, etc.)
///
/// ## Notes
///
/// - This function is used internally by `client.select_stream_messages()`
/// - Handles all message normalization and type conversion
/// - Returns a format optimized for Gleam's dynamic decoder
@external(erlang, "dream_httpc_shim", "decode_stream_message_for_selector")
pub fn decode_stream_message_for_selector(message: d.Dynamic) -> d.Dynamic
