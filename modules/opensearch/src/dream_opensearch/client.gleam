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
//// The base URL should point to your OpenSearch cluster. It can include a
//// user name and password, which the client sends as HTTP Basic
//// authentication on every request:
////
//// - `http://localhost:9200`
//// - `https://search.example.com:9200`
//// - `https://user:pass@search.example.com:9200`
////
//// Percent-encode `@`, `:` and `/` in the user name or password (`%40`,
//// `%3A`, `%2F`). The client decodes them before it builds the
//// `authorization` header.

import dream_http_client/client as http_client
import gleam/bit_array
import gleam/http
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// OpenSearch client configuration
///
/// Represents a connection to an OpenSearch cluster. The client stores the
/// base URL and handles HTTP communication with the cluster.
///
/// ## Fields
///
/// - `base_url`: The base URL of the OpenSearch cluster (without trailing
///   slash), as given to `new`. It keeps any user name and password; do not
///   print or log it.
pub type Client {
  Client(base_url: String)
}

/// Create a new OpenSearch client
///
/// Creates a client configured to connect to the specified OpenSearch cluster.
/// The base URL should include the protocol and port (e.g., `http://localhost:9200`).
///
/// Any trailing slash in the URL is automatically removed. The URL is not
/// checked here: `send_request` parses it on each request.
///
/// A user name and password in the URL (`https://user:pass@host:9200`) make
/// every request send HTTP Basic authentication. See `send_request`.
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
/// When the base URL has a user name, the request also has the header
/// `authorization: Basic <base64(user:password)>`. The user name and password
/// are percent-decoded first, and a URL with no password sends an empty
/// password. The user name and password are not sent in the request line or
/// the `host` header. A base URL with no user name sends no `authorization`
/// header.
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
/// - `Ok(String)`: The response body as a string (status < 400)
/// - `Error(String)`: The error response body (status >= 400), an error
///   message for connection failures, or an error message when the URL cannot
///   be parsed, has no host, or has invalid percent-encoding in the user name
///   or password. No error message contains the user name or password.
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
  use target <- result.try(parse_target(client.base_url <> path))
  target
  |> build_request(method, body)
  |> http_client.send
  |> response_to_result
}

/// Where a request goes, parsed from the base URL and the API path.
///
/// `authorization` holds the full `authorization` header value when the URL
/// has a user name. The user name and password never go in any other field.
type Target {
  Target(
    scheme: http.Scheme,
    host: String,
    port: Option(Int),
    path: String,
    query: Option(String),
    authorization: Option(String),
  )
}

fn parse_target(url: String) -> Result(Target, String) {
  use parsed <- result.try(
    uri.parse(url)
    |> result.replace_error("Invalid OpenSearch URL: the URL cannot be parsed"),
  )
  use host <- result.try(option.to_result(
    parsed.host,
    "Invalid OpenSearch URL: the URL has no host",
  ))
  use authorization <- result.try(parse_authorization(parsed.userinfo))
  Ok(Target(
    scheme: parse_scheme(parsed.scheme),
    host: host,
    port: parsed.port,
    path: path_or_root(parsed.path),
    query: parsed.query,
    authorization: authorization,
  ))
}

fn parse_scheme(scheme: Option(String)) -> http.Scheme {
  case scheme {
    Some("https") -> http.Https
    _ -> http.Http
  }
}

fn path_or_root(path: String) -> String {
  case path {
    "" -> "/"
    _ -> path
  }
}

fn parse_authorization(
  userinfo: Option(String),
) -> Result(Option(String), String) {
  case userinfo {
    None -> Ok(None)
    Some(encoded_userinfo) ->
      encoded_userinfo
      |> decode_credentials
      |> result.map(basic_authorization)
      |> result.map(Some)
  }
}

/// Splits `user:password` at the first `:` and percent-decodes both parts.
/// A userinfo with no `:` is a user name with an empty password.
/// The error message never holds the user name or the password.
fn decode_credentials(
  encoded_userinfo: String,
) -> Result(#(String, String), String) {
  let #(encoded_user, encoded_password) =
    string.split_once(encoded_userinfo, on: ":")
    |> result.unwrap(#(encoded_userinfo, ""))
  let invalid_encoding =
    "Invalid credentials in the OpenSearch URL: the user name or password has invalid percent-encoding"
  use user <- result.try(
    uri.percent_decode(encoded_user) |> result.replace_error(invalid_encoding),
  )
  use password <- result.try(
    uri.percent_decode(encoded_password)
    |> result.replace_error(invalid_encoding),
  )
  Ok(#(user, password))
}

fn basic_authorization(credentials: #(String, String)) -> String {
  let #(user, password) = credentials
  "Basic "
  <> bit_array.base64_encode(
    bit_array.from_string(user <> ":" <> password),
    True,
  )
}

fn build_request(
  target: Target,
  method: http.Method,
  body: String,
) -> http_client.ClientRequest {
  http_client.new()
  |> http_client.method(method)
  |> http_client.scheme(target.scheme)
  |> http_client.host(target.host)
  |> add_port(target.port)
  |> http_client.path(target.path)
  |> add_query(target.query)
  |> http_client.add_header("content-type", "application/json")
  |> add_authorization(target.authorization)
  |> http_client.body(body)
}

fn add_port(
  request: http_client.ClientRequest,
  port: Option(Int),
) -> http_client.ClientRequest {
  case port {
    Some(port_value) -> http_client.port(request, port_value)
    None -> request
  }
}

fn add_query(
  request: http_client.ClientRequest,
  query: Option(String),
) -> http_client.ClientRequest {
  case query {
    Some(query_value) -> http_client.query(request, query_value)
    None -> request
  }
}

fn add_authorization(
  request: http_client.ClientRequest,
  authorization: Option(String),
) -> http_client.ClientRequest {
  case authorization {
    Some(header_value) ->
      http_client.add_header(request, "authorization", header_value)
    None -> request
  }
}

fn response_to_result(
  response: Result(http_client.HttpResponse, http_client.SendError),
) -> Result(String, String) {
  case response {
    Ok(http_client.HttpResponse(body: body, ..)) -> Ok(body)
    Error(http_client.ResponseError(response: http_client.HttpResponse(
      body: body,
      ..,
    ))) -> Error(body)
    Error(http_client.RequestError(error: transport_error)) ->
      Error(http_client.transport_error_to_string(transport_error))
  }
}
