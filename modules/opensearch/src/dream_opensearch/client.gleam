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

import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/result
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
  let url = client.base_url <> path

  let assert Ok(req) = request.to(url)

  req
  |> request.set_method(method)
  |> request.set_body(body)
  |> request.prepend_header("content-type", "application/json")
  |> httpc.send()
  |> result.map_error(error_to_string)
  |> result.map(extract_body)
}

fn extract_body(response: Response(String)) -> String {
  response.body
}

fn error_to_string(_error: httpc.HttpError) -> String {
  "HTTP request failed"
}
