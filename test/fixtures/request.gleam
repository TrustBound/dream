//// Reusable request fixtures for tests.
////
//// Provides factory functions for creating test requests with sensible defaults.

import dream/http/request.{type Method, type Request, Http, Http1, Request}
import gleam/option

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
    body: "",
    stream: option.None,
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
  Request(..create_request(method, path), body: body)
}

/// Create request with query string.
pub fn create_request_with_query(
  method: Method,
  path: String,
  query: String,
) -> Request {
  Request(..create_request(method, path), query: query)
}
