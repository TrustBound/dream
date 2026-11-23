//// Reusable request fixtures for tests.
////
//// Provides factory functions for creating test requests with sensible defaults.

import dream/http/request.{
  type Method, type Request, Bytes, Http, Http1, Request, Stream, Text,
}
import gleam/bit_array
import gleam/list
import gleam/option
import gleam/yielder

/// Create a minimal test request with sensible defaults.
pub fn create_request(method: Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

/// Create request with a body.
pub fn create_request_with_body(
  method: Method,
  path: String,
  body: String,
) -> Request {
  Request(..create_request(method, path), body: Text(body))
}

/// Create request with a binary body.
pub fn create_request_with_bytes(
  method: Method,
  path: String,
  bytes: BitArray,
) -> Request {
  Request(..create_request(method, path), body: Bytes(bytes))
}

/// Create request with query string.
pub fn create_request_with_query(
  method: Method,
  path: String,
  query: String,
) -> Request {
  Request(..create_request(method, path), query: query)
}

/// Create request with URL parameters.
pub fn create_request_with_params(
  method: Method,
  path: String,
  params: List(#(String, String)),
) -> Request {
  Request(..create_request(method, path), params: params)
}

/// Create request with a streaming body.
pub fn create_streaming_request(
  method: Method,
  path: String,
  stream: yielder.Yielder(BitArray),
) -> Request {
  Request(..create_request(method, path), body: Stream(yielder.map(stream, Ok)))
}

/// Create request with a streaming body from string chunks.
pub fn create_streaming_request_from_strings(
  method: Method,
  path: String,
  chunks: List(String),
) -> Request {
  let stream =
    chunks
    |> list.map(bit_array.from_string)
    |> list.map(Ok)
    |> yielder.from_list
  Request(..create_request(method, path), body: Stream(stream))
}
