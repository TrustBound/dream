//// HTTP client builder for Dream web framework
////
//// This module provides a builder pattern for constructing HTTP client requests,
//// similar to the router pattern. It supports both streaming and non-streaming requests.
////
//// For making requests, import from:
//// - `dream/utilities/http/client/stream` for streaming requests
//// - `dream/utilities/http/client/fetch` for non-streaming requests

import gleam/http
import gleam/option.{type Option, None}

/// HTTP client request configuration
pub type ClientRequest {
  ClientRequest(
    method: http.Method,
    scheme: http.Scheme,
    host: String,
    port: Option(Int),
    path: String,
    query: Option(String),
    headers: List(#(String, String)),
    body: String,
  )
}

/// Default client request constant
pub const new = ClientRequest(
  method: http.Get,
  scheme: http.Https,
  host: "localhost",
  port: None,
  path: "",
  query: None,
  headers: [],
  body: "",
)

/// Set the HTTP method for the request
pub fn method(
  client_request: ClientRequest,
  method_value: http.Method,
) -> ClientRequest {
  ClientRequest(..client_request, method: method_value)
}

/// Set the scheme (protocol) for the request
pub fn scheme(
  client_request: ClientRequest,
  scheme_value: http.Scheme,
) -> ClientRequest {
  ClientRequest(..client_request, scheme: scheme_value)
}

/// Set the host for the request
pub fn host(client_request: ClientRequest, host_value: String) -> ClientRequest {
  ClientRequest(..client_request, host: host_value)
}

/// Set the port for the request
pub fn port(client_request: ClientRequest, port_value: Int) -> ClientRequest {
  ClientRequest(..client_request, port: option.Some(port_value))
}

/// Set the path for the request
pub fn path(client_request: ClientRequest, path_value: String) -> ClientRequest {
  ClientRequest(..client_request, path: path_value)
}

/// Set the query string for the request
pub fn query(
  client_request: ClientRequest,
  query_value: String,
) -> ClientRequest {
  ClientRequest(..client_request, query: option.Some(query_value))
}

/// Set the headers for the request
pub fn headers(
  client_request: ClientRequest,
  headers_value: List(#(String, String)),
) -> ClientRequest {
  ClientRequest(..client_request, headers: headers_value)
}

/// Set the body for the request
pub fn body(client_request: ClientRequest, body_value: String) -> ClientRequest {
  ClientRequest(..client_request, body: body_value)
}

/// Add a header to the request
pub fn add_header(
  client_request: ClientRequest,
  name: String,
  value: String,
) -> ClientRequest {
  ClientRequest(..client_request, headers: [
    #(name, value),
    ..client_request.headers
  ])
}
