//// OpenSearch HTTP client
////
//// This module provides a simple HTTP client for interacting with OpenSearch
//// (or Elasticsearch) clusters. It handles the low-level HTTP communication
//// needed for document operations, searches, and index management.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_opensearch/client
//// import dream_opensearch/document
////
//// let client = client.new("http://localhost:9200")
////
//// // Index a document
//// document.index(client, "users", "123", json_body)
//// ```
////
//// ## Base URL
////
//// The base URL should point to your OpenSearch cluster. It can include
//// authentication if needed:
////
//// - `http://localhost:9200`
//// - `https://search.example.com:9200`
//// - `https://user:pass@search.example.com:9200`

import dream_http_client/client as http_client
import gleam/http
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

/// OpenSearch client configuration
///
/// Represents a connection to an OpenSearch cluster. The client stores the
/// base URL and handles HTTP communication with the cluster.
///
/// ## Fields
///
/// - `base_url`: The base URL of the OpenSearch cluster (without trailing slash)
pub type Client {
  Client(base_url: String)
}

/// Create a new OpenSearch client
///
/// Creates a client configured to connect to the specified OpenSearch cluster.
/// The base URL should include the protocol and port (e.g., `http://localhost:9200`).
///
/// Any trailing slash in the URL is automatically removed.
///
/// ## Parameters
///
/// - `base_url`: The base URL of the OpenSearch cluster
///
/// ## Returns
///
/// A new `Client` configured for the specified cluster.
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/client
///
/// let client = client.new("http://localhost:9200")
/// // Or with authentication
/// let client = client.new("https://user:pass@search.example.com:9200")
/// ```
pub fn new(base_url: String) -> Client {
  let trimmed = case string.ends_with(base_url, "/") {
    True -> string.drop_end(base_url, 1)
    False -> base_url
  }
  Client(base_url: trimmed)
}

/// Send HTTP request to OpenSearch
///
/// Sends a raw HTTP request to the OpenSearch cluster. This is used internally
/// by the document and query modules. Most applications should use those
/// higher-level modules instead.
///
/// The request automatically includes the `Content-Type: application/json` header.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `method`: The HTTP method (GET, POST, PUT, DELETE, etc.)
/// - `path`: The API path (e.g., "/users/_doc/123" or "/users/_search")
/// - `body`: The request body as a JSON string
///
/// ## Returns
///
/// - `Ok(String)`: The response body as a string
/// - `Error(String)`: An error message if the request failed
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/client
/// import gleam/http
///
/// let result = client.send_request(
///   client,
///   http.Get,
///   "/users/_doc/123",
///   ""
/// )
/// ```
pub fn send_request(
  client: Client,
  method: http.Method,
  path: String,
  body: String,
) -> Result(String, String) {
  // Parse the base URL to extract scheme, host, and port
  let url = client.base_url <> path
  let #(scheme, host, port, path_part) = parse_url(url)

  let base_request =
    http_client.new
    |> http_client.method(method)
    |> http_client.scheme(scheme)
    |> http_client.host(host)
    |> http_client.path(path_part)
    |> http_client.add_header("content-type", "application/json")
    |> http_client.body(body)

  let request = case port {
    Some(port_value) -> http_client.port(base_request, port_value)
    None -> base_request
  }

  http_client.send(request)
}

fn parse_url(url: String) -> #(http.Scheme, String, Option(Int), String) {
  case string.split(url, on: "://") {
    [scheme_str, rest] -> {
      let scheme = parse_scheme(scheme_str)
      let #(host, port, path) = parse_host_and_path(rest)
      #(scheme, host, port, path)
    }
    _ -> #(http.Http, url, None, "/")
  }
}

fn parse_scheme(scheme_str: String) -> http.Scheme {
  case scheme_str {
    "http" -> http.Http
    "https" -> http.Https
    _ -> http.Http
  }
}

fn parse_host_and_path(rest: String) -> #(String, Option(Int), String) {
  case string.split(rest, on: "/") {
    [host_part, ..path_parts] -> {
      let path = "/" <> string.join(path_parts, with: "/")
      let #(host, port) = parse_host_and_port(host_part)
      #(host, port, path)
    }
    _ -> {
      let #(host, port) = parse_host_and_port(rest)
      #(host, port, "/")
    }
  }
}

fn parse_host_and_port(host_part: String) -> #(String, Option(Int)) {
  case string.split(host_part, on: ":") {
    [host] -> #(host, None)
    [host, port_str] -> {
      let port = parse_port(port_str)
      #(host, port)
    }
    _ -> #(host_part, None)
  }
}

fn parse_port(port_str: String) -> Option(Int) {
  case int.parse(port_str) {
    Ok(port) -> Some(port)
    Error(_) -> None
  }
}
