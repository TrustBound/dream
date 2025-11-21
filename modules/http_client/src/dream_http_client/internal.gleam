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
) -> d.Dynamic

@external(erlang, "dream_httpc_shim", "fetch_next")
fn fetch_next(owner: d.Dynamic) -> d.Dynamic

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
/// - `req`: The HTTP request to send
///
/// ## Returns
///
/// A dynamic value containing the owner PID in the format `{ok, OwnerPid}`.
/// Use `extract_owner_pid()` to get the PID for receiving chunks.
pub fn start_httpc_stream(req: Request(String)) -> d.Dynamic {
  let url = http.scheme_to_string(req.scheme) <> "://" <> req.host <> req.path
  let method_atom = atomize_method(req.method)
  let body = <<req.body:utf8>>
  let me = process.self()
  request_stream(method_atom, url, req.headers, body, me)
}

/// Extract the owner PID from the request result
///
/// Extracts the owner process ID from the result returned by `start_httpc_stream()`.
/// The owner PID is used to receive response chunks from the streaming request.
///
/// ## Parameters
///
/// - `request_result`: The dynamic result from `start_httpc_stream()`
///
/// ## Returns
///
/// The owner PID as a dynamic value, or the original result if extraction fails.
pub fn extract_owner_pid(request_result: d.Dynamic) -> d.Dynamic {
  // Expect {ok, OwnerPid}
  let decoded = d.run(request_result, d.at([1], d.dynamic))
  case decoded {
    Ok(id) -> id
    Error(_) -> request_result
  }
}

/// Receive the next chunk from the stream
///
/// Receives the next chunk of data from an active streaming HTTP request.
/// Returns `Ok(BitArray)` when a chunk is available, or `Error(Nil)` when
/// the stream has finished or an error occurred.
///
/// ## Parameters
///
/// - `owner`: The owner PID from `extract_owner_pid()`
///
/// ## Returns
///
/// - `Ok(BitArray)`: The next chunk of response data
/// - `Error(Nil)`: Stream finished or error occurred
pub fn receive_next(owner: d.Dynamic) -> Result(BitArray, Nil) {
  let resp = fetch_next(owner)
  let tag =
    d.run(resp, d.at([0], d.dynamic))
    |> result.try(fn(dyn) { Ok(atom.cast_from_dynamic(dyn)) })
    |> result.unwrap(atom.create(""))
    |> atom.to_string
  case tag {
    "chunk" -> {
      let bin = d.run(resp, d.at([1], d.bit_array)) |> result.unwrap(<<>>)
      Ok(bin)
    }
    "finished" -> Error(Nil)
    _ -> Error(Nil)
  }
}
