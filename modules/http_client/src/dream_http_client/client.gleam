//// HTTP client for making requests
////
//// Gleam doesn't have a built-in HTTPS client, so Dream wraps Erlang's battle-hardened
//// `httpc`. Use this for calling external APIs, downloading files, or streaming AI responses.
////
//// ## Quick Example
////
//// ```gleam
//// import dream_http_client/client
//// import dream_http_client/fetch
//// import gleam/http
////
//// pub fn call_api() {
////   client.new
////   |> client.host("api.example.com")
////   |> client.path("/users/123")
////   |> client.header("Authorization", "Bearer " <> token)
////   |> fetch.send()
//// }
//// ```
////
//// ## Streaming vs Fetch
////
//// - `fetch`: Get the whole response at once. Good for API calls, JSON responses.
//// - `stream`: Get a yielder that streams chunks. Good for large files, AI responses.
////
//// ```gleam
//// import dream_http_client/stream
////
//// // Stream large file
//// client.new
//// |> client.host("cdn.example.com")
//// |> client.path("/large-file.zip")
//// |> stream.send()
//// |> yielder.each(process_chunk)
//// ```

import gleam/http
import gleam/option.{type Option, None}

/// HTTP client request configuration
///
/// Represents a complete HTTP request with all its components. Use the builder
/// pattern with functions like `host()`, `path()`, `method()`, etc. to configure
/// the request, then send it with `fetch.send()` or `stream.send()`.
///
/// ## Fields
///
/// - `method`: The HTTP method (GET, POST, etc.)
/// - `scheme`: The protocol (HTTP or HTTPS)
/// - `host`: The server hostname
/// - `port`: Optional port number (defaults to 80 for HTTP, 443 for HTTPS)
/// - `path`: The request path (e.g., "/api/users")
/// - `query`: Optional query string (e.g., "?page=1&limit=10")
/// - `headers`: List of header name-value pairs
/// - `body`: The request body as a string
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

/// Default client request configuration
///
/// Creates a new `ClientRequest` with sensible defaults:
/// - Method: GET
/// - Scheme: HTTPS
/// - Host: "localhost"
/// - Port: None (uses default for scheme)
/// - Path: "" (empty)
/// - Query: None
/// - Headers: [] (empty)
/// - Body: "" (empty)
///
/// Use this as the starting point for building requests with the builder pattern.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.host("api.example.com")
/// |> client.path("/users/123")
/// |> client.method(http.Get)
/// ```
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
///
/// Configures the HTTP method (GET, POST, PUT, DELETE, etc.) for the request.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `method_value`: The HTTP method to use
///
/// ## Returns
///
/// A new `ClientRequest` with the method updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import gleam/http
///
/// client.new
/// |> client.method(http.Post)
/// ```
pub fn method(
  client_request: ClientRequest,
  method_value: http.Method,
) -> ClientRequest {
  ClientRequest(..client_request, method: method_value)
}

/// Set the scheme (protocol) for the request
///
/// Configures whether to use HTTP or HTTPS. Defaults to HTTPS for security.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `scheme_value`: The protocol scheme (`http.Http` or `http.Https`)
///
/// ## Returns
///
/// A new `ClientRequest` with the scheme updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import gleam/http
///
/// client.new
/// |> client.scheme(http.Http)  // Use HTTP instead of HTTPS
/// ```
pub fn scheme(
  client_request: ClientRequest,
  scheme_value: http.Scheme,
) -> ClientRequest {
  ClientRequest(..client_request, scheme: scheme_value)
}

/// Set the host for the request
///
/// Sets the server hostname or IP address. This is required for all requests.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `host_value`: The hostname (e.g., "api.example.com" or "192.168.1.1")
///
/// ## Returns
///
/// A new `ClientRequest` with the host updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.host("api.example.com")
/// ```
pub fn host(client_request: ClientRequest, host_value: String) -> ClientRequest {
  ClientRequest(..client_request, host: host_value)
}

/// Set the port for the request
///
/// Sets a custom port number. If not set, defaults to 80 for HTTP and 443
/// for HTTPS. Only set this if you're using a non-standard port.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `port_value`: The port number (e.g., 8080, 3000)
///
/// ## Returns
///
/// A new `ClientRequest` with the port updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.host("localhost")
/// |> client.port(3000)  // Use port 3000 instead of default
/// ```
pub fn port(client_request: ClientRequest, port_value: Int) -> ClientRequest {
  ClientRequest(..client_request, port: option.Some(port_value))
}

/// Set the path for the request
///
/// Sets the request path. Should start with "/" for absolute paths.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `path_value`: The path (e.g., "/api/users" or "/api/users/123")
///
/// ## Returns
///
/// A new `ClientRequest` with the path updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.path("/api/users/123")
/// ```
pub fn path(client_request: ClientRequest, path_value: String) -> ClientRequest {
  ClientRequest(..client_request, path: path_value)
}

/// Set the query string for the request
///
/// Sets the query string portion of the URL. Do not include the leading "?".
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `query_value`: The query string (e.g., "page=1&limit=10")
///
/// ## Returns
///
/// A new `ClientRequest` with the query string updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.path("/api/users")
/// |> client.query("page=1&limit=10")
/// ```
pub fn query(
  client_request: ClientRequest,
  query_value: String,
) -> ClientRequest {
  ClientRequest(..client_request, query: option.Some(query_value))
}

/// Set the headers for the request
///
/// Replaces all existing headers with the provided list. Use `add_header()`
/// to add a single header without replacing existing ones.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `headers_value`: List of header tuples `#(name, value)`
///
/// ## Returns
///
/// A new `ClientRequest` with headers replaced.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.headers([
///   #("Authorization", "Bearer " <> token),
///   #("Content-Type", "application/json"),
/// ])
/// ```
pub fn headers(
  client_request: ClientRequest,
  headers_value: List(#(String, String)),
) -> ClientRequest {
  ClientRequest(..client_request, headers: headers_value)
}

/// Set the body for the request
///
/// Sets the request body as a string. Typically used for POST, PUT, and PATCH
/// requests. For JSON, serialize your data first.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `body_value`: The request body as a string
///
/// ## Returns
///
/// A new `ClientRequest` with the body updated.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import gleam/json
///
/// let json_body = json.object([
///   #("name", json.string("Alice")),
///   #("email", json.string("alice@example.com")),
/// ])
///
/// client.new
/// |> client.method(http.Post)
/// |> client.body(json.to_string(json_body))
/// ```
pub fn body(client_request: ClientRequest, body_value: String) -> ClientRequest {
  ClientRequest(..client_request, body: body_value)
}

/// Add a header to the request
///
/// Adds a single header to the existing headers list without replacing them.
/// The new header is prepended to the list, so it will take precedence if
/// there's a duplicate header name.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `name`: The header name (e.g., "Authorization", "Content-Type")
/// - `value`: The header value
///
/// ## Returns
///
/// A new `ClientRequest` with the header added.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// client.new
/// |> client.add_header("Authorization", "Bearer " <> token)
/// |> client.add_header("Content-Type", "application/json")
/// ```
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
