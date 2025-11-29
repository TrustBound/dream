//// Type-safe HTTP client with streaming support
////
//// Gleam doesn't have a built-in HTTPS client, so this module wraps Erlang's battle-hardened
//// `httpc`. Use this for calling external APIs, downloading files, streaming AI responses,
//// or building OTP-compatible services with concurrent HTTP streams.
////
//// ## Quick Example - Blocking Request
////
//// ```gleam
//// import dream_http_client/client.{host, path, add_header, send}
////
//// pub fn call_api() {
////   let result = client.new
////     |> host("api.example.com")
////     |> path("/users/123")
////     |> add_header("Authorization", "Bearer " <> token)
////     |> send()
////
////   case result {
////     Ok(body) -> decode_json(body)
////     Error(msg) -> handle_error(msg)
////   }
//// }
//// ```
////
//// ## Execution Modes
////
//// This module provides three ways to execute HTTP requests:
////
//// ### 1. Blocking - `client.send()`
////
//// Get the complete response at once. Perfect for:
//// - JSON API calls
//// - Small files or documents
//// - Any case where you need the full response before processing
////
//// ### 2. Yielder Streaming - `client.stream_yielder()`
////
//// Get a `yielder.Yielder` that produces chunks sequentially. Perfect for:
//// - AI/LLM inference endpoints (streaming tokens)
//// - Simple file downloads
//// - Scripts or one-off operations
////
//// **Note:** This is a pull-based synchronous API. It blocks the calling process
//// while waiting for chunks, making it unsuitable for OTP actors that need to
//// handle multiple concurrent operations.
////
//// ```gleam
//// import dream_http_client/client.{host, path, stream_yielder}
//// import gleam/yielder.{each}
//// import gleam/bytes_tree.{to_string}
//// import gleam/io.{print, println_error}
////
//// client.new
//// |> host("api.openai.com")
//// |> path("/v1/chat/completions")
//// |> stream_yielder()
//// |> each(fn(result) {
////   case result {
////     Ok(chunk) -> print(to_string(chunk))
////     Error(reason) -> println_error("Stream error: " <> reason)
////   }
//// })
//// ```
////
//// ### 3. Message-Based Streaming - `client.stream_messages()`
////
//// Get messages sent to your process mailbox. Perfect for:
//// - OTP actors handling multiple concurrent streams
//// - Long-lived connections that need cancellation
//// - Integration with OTP supervisors and selectors
////
//// This is a push-based asynchronous API fully compatible with OTP patterns.
////
//// ```gleam
//// import dream_http_client/client.{
////   type StreamMessage, Chunk, StreamEnd, StreamError, StreamStart,
////   select_stream_messages
//// }
//// import gleam/otp/actor.{continue}
//// import gleam/erlang/process.{new_selector}
////
//// pub type Message {
////   HttpStream(StreamMessage)
//// }
////
//// fn init_selector() {
////   new_selector()
////   |> select_stream_messages(HttpStream)
//// }
////
//// fn handle_message(msg: Message, state: State) {
////   case msg {
////     HttpStream(Chunk(req_id, data)) -> process_chunk(data, state)
////     HttpStream(StreamEnd(req_id, _)) -> cleanup(req_id, state)
////     HttpStream(StreamError(req_id, reason)) -> handle_error(req_id, reason, state)
////     HttpStream(StreamStart(_, _)) -> continue(state)
////     HttpStream(DecodeError(reason)) -> {
////       // FFI corruption - report as bug
////       log_critical_error("DecodeError: " <> reason)
////       continue(state)
////     }
////   }
//// }
//// ```
////
//// ## Configuration
////
//// All execution modes support the same builder pattern for configuration:
//// - **Timeouts**: Use `timeout()` to set request timeout (default: 30 seconds)
//// - **Headers**: Use `add_header()` for incremental or `headers()` for batch
//// - **Method/Path/Query**: Standard HTTP request components
////
//// Example with timeout:
////
//// ```gleam
//// import dream_http_client/client.{host, timeout, send}
////
//// client.new
//// |> host("slow-api.example.com")
//// |> timeout(60_000)  // 60 second timeout
//// |> send()
//// ```
////
//// ## Inspecting Requests
////
//// The `ClientRequest` type is opaque to ensure API stability. Use getter functions
//// to inspect request properties for logging, testing, or middleware:
////
//// ```gleam
//// import dream_http_client/client
//// import gleam/io
////
//// let req = client.new
////   |> client.host("api.example.com")
////   |> client.path("/users/123")
////
//// // Inspect the request before sending
//// io.println("Calling: " <> client.get_host(req) <> client.get_path(req))
//// // Prints: "Calling: api.example.com/users/123"
////
//// let result = client.send(req)
//// ```
////
//// Available getters: `get_method`, `get_scheme`, `get_host`, `get_port`, `get_path`,
//// `get_query`, `get_headers`, `get_body`, `get_timeout`, `get_recorder`

import dream_http_client/internal
import dream_http_client/recorder
import dream_http_client/recording
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode as d
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/yielder

/// HTTP client request configuration
///
/// Represents a complete HTTP request with all its components. Use the builder
/// pattern with functions like `host()`, `path()`, `method()`, etc. to configure
/// the request, then execute it with `send/1`, `stream_yielder/1`, or
/// `stream_messages/1` depending on whether you want a blocking, yielder-based,
/// or message-based streaming API.
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
/// - `timeout`: Optional timeout in milliseconds (defaults to 30000ms)
/// - `recorder`: Optional recorder for request/response recording and playback
///
/// The type is opaque to ensure API stability. Use `new` with builder functions
/// to construct requests, and the getter functions to inspect request properties.
pub opaque type ClientRequest {
  ClientRequest(
    method: http.Method,
    scheme: http.Scheme,
    host: String,
    port: Option(Int),
    path: String,
    query: Option(String),
    headers: List(#(String, String)),
    body: String,
    timeout: Option(Int),
    recorder: Option(recorder.Recorder),
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
/// - Timeout: None (uses default 30000ms)
///
/// Use this as the starting point for building requests with the builder pattern.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{host, path, method}
/// import gleam/http.{Get}
///
/// client.new
/// |> host("api.example.com")
/// |> path("/users/123")
/// |> method(Get)
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
  timeout: None,
  recorder: None,
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

/// Set the recorder for the request
///
/// Attaches a recorder to the request for recording or playback.
/// The recorder must be started with `recorder.start()` before use.
///
/// ## Parameters
///
/// - `client_request`: The request to modify
/// - `recorder_value`: The recorder to attach
///
/// ## Returns
///
/// A new `ClientRequest` with the recorder attached.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import dream_http_client/recorder
///
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: recorder.match_url_only(),
/// )
///
/// client.new
/// |> client.host("api.example.com")
/// |> client.recorder(rec)
/// ```
pub fn recorder(
  client_request: ClientRequest,
  recorder_value: recorder.Recorder,
) -> ClientRequest {
  ClientRequest(..client_request, recorder: Some(recorder_value))
}

/// Set the timeout for the request in milliseconds
///
/// Sets how long to wait for a response before timing out. If not set,
/// defaults to 30000ms (30 seconds).
///
/// ## Parameters
///
/// - `timeout_ms`: Timeout duration in milliseconds
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{host, timeout}
///
/// client.new
/// |> host("slow-api.example.com")
/// |> timeout(60_000)  // 60 second timeout
/// ```
pub fn timeout(client_request: ClientRequest, timeout_ms: Int) -> ClientRequest {
  ClientRequest(..client_request, timeout: option.Some(timeout_ms))
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

// ============================================================================
// Request Inspection (Getters)
// ============================================================================

/// Get the HTTP method from a request
///
/// Returns the HTTP method (GET, POST, etc.) configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import gleam/http.{Post}
///
/// let req = client.new |> client.method(Post)
/// let method = client.get_method(req)
/// // method == Post
/// ```
pub fn get_method(client_request: ClientRequest) -> http.Method {
  client_request.method
}

/// Get the URI scheme from a request
///
/// Returns the scheme (HTTP or HTTPS) configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import gleam/http.{Http}
///
/// let req = client.new |> client.scheme(Http)
/// let scheme = client.get_scheme(req)
/// // scheme == Http
/// ```
pub fn get_scheme(client_request: ClientRequest) -> http.Scheme {
  client_request.scheme
}

/// Get the host from a request
///
/// Returns the hostname configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.host("api.example.com")
/// let host = client.get_host(req)
/// // host == "api.example.com"
/// ```
pub fn get_host(client_request: ClientRequest) -> String {
  client_request.host
}

/// Get the port from a request
///
/// Returns the optional port number configured for the request.
/// If None, the default port for the scheme will be used (80 for HTTP, 443 for HTTPS).
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.port(8080)
/// let port = client.get_port(req)
/// // port == Some(8080)
/// ```
pub fn get_port(client_request: ClientRequest) -> Option(Int) {
  client_request.port
}

/// Get the path from a request
///
/// Returns the request path configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.path("/api/users")
/// let path = client.get_path(req)
/// // path == "/api/users"
/// ```
pub fn get_path(client_request: ClientRequest) -> String {
  client_request.path
}

/// Get the query string from a request
///
/// Returns the optional query string configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.query("page=1&limit=10")
/// let query = client.get_query(req)
/// // query == Some("page=1&limit=10")
/// ```
pub fn get_query(client_request: ClientRequest) -> Option(String) {
  client_request.query
}

/// Get the headers from a request
///
/// Returns the list of headers configured for the request.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new
///   |> client.add_header("Authorization", "Bearer token")
///   |> client.add_header("Content-Type", "application/json")
/// let headers = client.get_headers(req)
/// // headers == [#("Content-Type", "application/json"), #("Authorization", "Bearer token")]
/// ```
pub fn get_headers(client_request: ClientRequest) -> List(#(String, String)) {
  client_request.headers
}

/// Get the body from a request
///
/// Returns the request body as a string.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.body("{\"name\": \"Alice\"}")
/// let body = client.get_body(req)
/// // body == "{\"name\": \"Alice\"}"
/// ```
pub fn get_body(client_request: ClientRequest) -> String {
  client_request.body
}

/// Get the timeout from a request
///
/// Returns the optional timeout in milliseconds configured for the request.
/// If None, the default timeout (30000ms) will be used.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
///
/// let req = client.new |> client.timeout(5000)
/// let timeout = client.get_timeout(req)
/// // timeout == Some(5000)
/// ```
pub fn get_timeout(client_request: ClientRequest) -> Option(Int) {
  client_request.timeout
}

/// Get the recorder from a request
///
/// Returns the optional recorder attached to the request for recording or playback.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client
/// import dream_http_client/recorder
/// import dream_http_client/matching
///
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
/// let req = client.new |> client.recorder(rec)
/// let recorder_opt = client.get_recorder(req)
/// // recorder_opt == Some(rec)
/// ```
pub fn get_recorder(client_request: ClientRequest) -> Option(recorder.Recorder) {
  client_request.recorder
}

// ============================================================================
// Message-Based Streaming Types
// ============================================================================

/// Opaque request identifier for message-based streaming
///
/// Returned by `stream_messages()` and used to identify which stream a message
/// belongs to when handling multiple concurrent streams.
pub opaque type RequestId {
  RequestId(id: String)
}

/// Stream message types sent to your process mailbox
///
/// When using `stream_messages()`, httpc sends these messages directly to your
/// process. Use `select_stream_messages()` to integrate with OTP selectors.
///
/// ## Message Flow
///
/// 1. `StreamStart` - Headers received, body chunks coming
/// 2. `Chunk` - Zero or more data chunks
/// 3. `StreamEnd` or `StreamError` - Stream completed normally
/// 4. `DecodeError` - FFI layer corruption (rare, should be reported as a bug)
///
/// ## DecodeError
///
/// `DecodeError` indicates the Erlang→Gleam FFI boundary received a malformed
/// message from `httpc`. This is **not a normal HTTP error** - it means either:
///
/// - Erlang/OTP version incompatibility with this library
/// - Memory corruption or other serious runtime issue
/// - A bug in this library's FFI code
///
/// **What to do:** If you see a `DecodeError`, please report it as a bug at
/// https://github.com/maxdeviant/dream/issues with the full error message.
/// The error message includes debug information to help diagnose the issue.
///
/// Unlike `StreamError` which has a `RequestId`, `DecodeError` does not because
/// the request ID itself could not be decoded from the corrupted message.
pub type StreamMessage {
  /// Stream started, headers received
  StreamStart(request_id: RequestId, headers: List(#(String, String)))
  /// Data chunk received
  Chunk(request_id: RequestId, data: BitArray)
  /// Stream completed successfully
  StreamEnd(request_id: RequestId, headers: List(#(String, String)))
  /// Stream failed with error (connection drop, timeout, HTTP error, etc.)
  StreamError(request_id: RequestId, reason: String)
  /// Failed to decode stream message from Erlang FFI (indicates library bug)
  DecodeError(reason: String)
}

// ============================================================================
// Request Execution
// ============================================================================

/// Make a blocking HTTP request and get the complete response
///
/// Sends an HTTP request and collects all response chunks, returning the
/// complete response body as a string. This is ideal for:
///
/// - JSON API responses
/// - Small files or documents
/// - Any case where you need the full response before processing
///
/// For large responses or when you need OTP compatibility, use
/// `stream_yielder()` or `stream_messages()` instead.
///
/// ## Parameters
///
/// - `client_request`: The configured HTTP request
///
/// ## Returns
///
/// - `Ok(String)`: The complete response body as a string
/// - `Error(String)`: An error message if the request failed
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{host, path, add_header, send}
/// import gleam/json.{decode}
///
/// let result = client.new
///   |> host("api.example.com")
///   |> path("/users/123")
///   |> add_header("Authorization", "Bearer " <> token)
///   |> send()
///
/// case result {
///   Ok(body) -> {
///     case decode(body, user_decoder) {
///       Ok(user) -> Ok(user)
///       Error(json_error) ->
///         Error("Invalid JSON response: " <> string.inspect(json_error))
///     }
///   }
///   Error(error_message) -> Error("Request failed: " <> error_message)
/// }
/// ```
pub fn send(client_request: ClientRequest) -> Result(String, String) {
  case client_request.recorder {
    option.Some(recorder_instance) ->
      send_with_recorder(client_request, recorder_instance)
    option.None -> send_without_recorder(client_request)
  }
}

fn send_without_recorder(
  client_request: ClientRequest,
) -> Result(String, String) {
  send_client_request_to_httpc(client_request)
}

fn send_with_recorder(
  client_request: ClientRequest,
  recorder_instance: recorder.Recorder,
) -> Result(String, String) {
  let recorded_request = client_request_to_recorded_request(client_request)

  case recorder.find_recording(recorder_instance, recorded_request) {
    option.Some(recording.Recording(_, response)) ->
      handle_recorded_blocking_response(response)
    option.None ->
      send_and_maybe_record(client_request, recorder_instance, recorded_request)
  }
}

fn handle_recorded_blocking_response(
  response: recording.RecordedResponse,
) -> Result(String, String) {
  case response {
    recording.BlockingResponse(_, _, body) -> Ok(body)
    recording.StreamingResponse(_, _, _) ->
      Error(
        "Recording contains streaming response, use stream_yielder() instead",
      )
  }
}

fn send_and_maybe_record(
  client_request: ClientRequest,
  recorder_instance: recorder.Recorder,
  recorded_request: recording.RecordedRequest,
) -> Result(String, String) {
  case send_client_request_to_httpc(client_request) {
    Ok(body) -> {
      record_blocking_response_if_needed(
        recorder_instance,
        recorded_request,
        body,
      )
      Ok(body)
    }
    Error(error_message) -> Error(error_message)
  }
}

fn record_blocking_response_if_needed(
  recorder_instance: recorder.Recorder,
  recorded_request: recording.RecordedRequest,
  body: String,
) -> Nil {
  case recorder.is_record_mode(recorder_instance) {
    True -> {
      let recorded_response =
        recording.BlockingResponse(
          status: 200,
          // TODO: get actual status from response
          headers: [],
          body: body,
        )
      let recorder_entry =
        recording.Recording(
          request: recorded_request,
          response: recorded_response,
        )
      recorder.add_recording(recorder_instance, recorder_entry)
    }
    False -> Nil
  }
}

fn send_client_request_to_httpc(
  client_request: ClientRequest,
) -> Result(String, String) {
  let http_request = to_http_request(client_request)
  let url = build_url(http_request)
  let method_atom = internal.atomize_method(http_request.method)
  let method_dynamic = atom.to_dynamic(method_atom)
  let body = <<http_request.body:utf8>>
  let timeout_value = resolve_timeout(client_request)

  case
    send_sync(method_dynamic, url, http_request.headers, body, timeout_value)
  {
    Ok(response_body) -> {
      response_body
      |> bit_array.to_string
      |> result.map_error(convert_string_error)
    }
    Error(error_message) -> Error(error_message)
  }
}

fn client_request_to_recorded_request(
  client_request: ClientRequest,
) -> recording.RecordedRequest {
  recording.RecordedRequest(
    method: client_request.method,
    scheme: client_request.scheme,
    host: client_request.host,
    port: client_request.port,
    path: client_request.path,
    query: client_request.query,
    headers: client_request.headers,
    body: client_request.body,
  )
}

fn convert_string_error(_unused: Nil) -> String {
  // BitArray.to_string uses Nil for string conversion errors, so there is no
  // additional error information to surface here.
  "Failed to convert response to string"
}

fn resolve_timeout(client_request: ClientRequest) -> Int {
  case client_request.timeout {
    Some(timeout_value) -> timeout_value
    None -> 30_000
  }
}

@external(erlang, "dream_httpc_shim", "request_sync")
fn send_sync(
  method: d.Dynamic,
  url: String,
  headers: List(#(String, String)),
  body: BitArray,
  timeout_ms: Int,
) -> Result(BitArray, String)

/// Stream HTTP response chunks using a yielder
///
/// Sends an HTTP request and returns a yielder that produces chunks of the
/// response body as they arrive from the server. This allows you to process
/// large responses incrementally without loading the entire response into memory.
///
/// **Use this for simple sequential streaming:**
/// - AI/LLM inference endpoints (stream tokens)
/// - Simple file downloads
/// - Scripts or one-off operations
///
/// **For OTP actors with concurrency, use `stream_messages()` instead.**
///
/// ## Error Semantics
///
/// The yielder produces `Result(BytesTree, String)` for each chunk:
/// - `Ok(chunk)` - Successful chunk, more may follow
/// - `Error(reason)` - **Terminal error**, stream is done
///
/// After an `Error`, the yielder immediately returns `Done` on the next call.
/// This design reflects that HTTP stream errors (timeouts, connection drops,
/// etc.) are **not recoverable** - you cannot continue reading from a broken stream.
///
/// **Normal stream completion**: When the stream finishes successfully, the yielder
/// returns `Done` (no more items). The stream does NOT yield an error for normal completion.
///
/// Possible error reasons (actual errors only):
/// - `"timeout"` - Request timed out
/// - Connection errors from `httpc`
///
/// ## Parameters
///
/// - `client_request`: The configured HTTP request
///
/// ## Returns
///
/// A `Yielder` that produces `Result(BytesTree, String)`. Always check each
/// result - errors are terminal and mean the stream has ended.
///
/// ## Examples
///
/// **Streaming and processing chunks as they arrive:**
///
/// ```gleam
/// import dream_http_client/client.{host, path, stream_yielder}
/// import gleam/yielder.{each}
/// import gleam/bytes_tree.{to_string}
/// import gleam/io.{print, println_error}
///
/// client.new
///   |> host("api.openai.com")
///   |> path("/v1/chat/completions")
///   |> stream_yielder()
///   |> each(fn(result) {
///     case result {
///       Ok(chunk) -> print(to_string(chunk))
///       Error(error_reason) -> {
///         println_error("Stream error: " <> error_reason)
///         // Stream is now done, no more chunks will arrive
///       }
///     }
///   })
/// ```
///
/// **Collecting all chunks into a list:**
///
/// ```gleam
/// import dream_http_client/client.{host, path, stream_yielder}
/// import gleam/yielder
/// import gleam/list
/// import gleam/bytes_tree
/// import gleam/string
///
/// // The stream automatically completes when done - no need to use take()!
/// let chunks = 
///   client.new
///   |> host("example.com")
///   |> path("/data")
///   |> stream_yielder()
///   |> yielder.to_list()
///
/// // Handle results
/// case list.try_map(chunks, fn(result) { result }) {
///   Ok(chunk_list) -> {
///     // Concatenate all chunks
///     let body = 
///       chunk_list
///       |> list.map(bytes_tree.to_string)
///       |> list.map(fn(chunk_result) { result.unwrap(chunk_result, "") })
///       |> string.join("")
///     Ok(body)
///   }
///   Error(error_reason) -> Error("Stream failed: " <> error_reason)
/// }
/// ```
pub fn stream_yielder(
  client_request: ClientRequest,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  case client_request.recorder {
    option.Some(recorder_instance) ->
      stream_yielder_with_recorder(client_request, recorder_instance)
    option.None -> create_stream_yielder_from_client_request(client_request)
  }
}

fn stream_yielder_with_recorder(
  client_request: ClientRequest,
  recorder_instance: recorder.Recorder,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  let recorded_request = client_request_to_recorded_request(client_request)

  case recorder.find_recording(recorder_instance, recorded_request) {
    option.Some(recording.Recording(_, response)) ->
      create_yielder_from_recorded_response(response)
    option.None -> create_stream_yielder_from_client_request(client_request)
  }
}

fn create_yielder_from_recorded_response(
  response: recording.RecordedResponse,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  case response {
    recording.StreamingResponse(_, _, chunks) ->
      create_yielder_from_chunks(chunks)
    recording.BlockingResponse(_, _, body) -> {
      // Blocking response - return as single chunk
      let chunk = bytes_tree.from_bit_array(<<body:utf8>>)
      yielder.single(Ok(chunk))
    }
  }
}

fn create_stream_yielder_from_client_request(
  client_request: ClientRequest,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  let http_request = to_http_request(client_request)
  let timeout_value = resolve_timeout(client_request)

  case client_request.recorder {
    option.Some(recorder_instance) ->
      stream_yielder_with_record_mode(
        client_request,
        recorder_instance,
        http_request,
        timeout_value,
      )
    option.None -> create_plain_yielder(http_request, timeout_value)
  }
}

fn stream_yielder_with_record_mode(
  client_request: ClientRequest,
  recorder_instance: recorder.Recorder,
  http_request: request.Request(String),
  timeout_value: Int,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  case recorder.is_record_mode(recorder_instance) {
    True -> {
      // Recording mode - wrap yielder to capture chunks
      let recorded_request = client_request_to_recorded_request(client_request)
      let initial_state =
        RecordingYielderState(
          owner: None,
          http_req: http_request,
          timeout_ms: timeout_value,
          recorder: recorder_instance,
          recorded_request: recorded_request,
          chunks: [],
          last_chunk_time: None,
        )
      yielder.unfold(initial_state, handle_recording_yielder_unfold)
    }
    False ->
      // Playback mode was already handled, use normal yielder
      create_plain_yielder(http_request, timeout_value)
  }
}

fn create_plain_yielder(
  http_request: request.Request(String),
  timeout_value: Int,
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  let initial_state =
    YielderState(owner: None, http_req: http_request, timeout_ms: timeout_value)
  yielder.unfold(initial_state, handle_yielder_unfold_with_deps)
}

fn create_yielder_from_chunks(
  chunks: List(recording.Chunk),
) -> yielder.Yielder(Result(bytes_tree.BytesTree, String)) {
  chunks
  |> yielder.from_list
  |> yielder.map(convert_chunk_to_result)
}

fn convert_chunk_to_result(
  chunk: recording.Chunk,
) -> Result(bytes_tree.BytesTree, String) {
  // TODO: Add delay based on chunk.delay_ms
  let data = bytes_tree.from_bit_array(chunk.data)
  Ok(data)
}

type YielderState {
  YielderState(
    owner: Option(d.Dynamic),
    http_req: request.Request(String),
    timeout_ms: Int,
  )
}

type RecordingYielderState {
  RecordingYielderState(
    owner: Option(d.Dynamic),
    http_req: request.Request(String),
    timeout_ms: Int,
    recorder: recorder.Recorder,
    recorded_request: recording.RecordedRequest,
    chunks: List(recording.Chunk),
    last_chunk_time: Option(Int),
  )
}

fn handle_yielder_unfold_with_deps(
  state: YielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), YielderState) {
  case state.owner {
    None -> handle_yielder_start_with_state(state)
    Some(owner) -> handle_yielder_next_with_state(owner, state)
  }
}

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

fn handle_yielder_start_with_state(
  state: YielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), YielderState) {
  let request_result =
    internal.start_httpc_stream(state.http_req, state.timeout_ms)
  let owner = internal.extract_owner_pid(request_result)
  case internal.receive_next(owner, state.timeout_ms) {
    Ok(option.Some(bin)) ->
      yielder.Next(
        Ok(bytes_tree.from_bit_array(bin)),
        YielderState(..state, owner: Some(owner)),
      )
    Ok(option.None) -> yielder.Done
    Error(error_reason) -> yielder.Next(Error(error_reason), state)
  }
}

fn handle_yielder_next_with_state(
  owner: d.Dynamic,
  state: YielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), YielderState) {
  case internal.receive_next(owner, state.timeout_ms) {
    Ok(option.Some(bin)) ->
      yielder.Next(Ok(bytes_tree.from_bit_array(bin)), state)
    Ok(option.None) -> yielder.Done
    Error(error_reason) -> yielder.Next(Error(error_reason), state)
  }
}

// Get current time in milliseconds for recording delays
@external(erlang, "erlang", "monotonic_time")
fn monotonic_time_native() -> Int

fn get_time_ms() -> Int {
  // Convert native time units to milliseconds
  let native = monotonic_time_native()
  // erlang:convert_time_unit(native, native, millisecond)
  convert_time_unit(native, atom.create("native"), atom.create("millisecond"))
}

@external(erlang, "erlang", "convert_time_unit")
fn convert_time_unit(time: Int, from_unit: atom.Atom, to_unit: atom.Atom) -> Int

fn handle_recording_yielder_unfold(
  state: RecordingYielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), RecordingYielderState) {
  case state.owner {
    None -> handle_recording_yielder_start(state)
    Some(owner) -> handle_recording_yielder_next(owner, state)
  }
}

fn handle_recording_yielder_start(
  state: RecordingYielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), RecordingYielderState) {
  let request_result =
    internal.start_httpc_stream(state.http_req, state.timeout_ms)
  let owner = internal.extract_owner_pid(request_result)
  let now = get_time_ms()

  case internal.receive_next(owner, state.timeout_ms) {
    Ok(option.Some(bin)) -> {
      // First chunk - record it
      let chunk = recording.Chunk(data: bin, delay_ms: 0)
      let new_state =
        RecordingYielderState(
          ..state,
          owner: Some(owner),
          chunks: [chunk],
          last_chunk_time: Some(now),
        )
      yielder.Next(Ok(bytes_tree.from_bit_array(bin)), new_state)
    }
    Ok(option.None) -> {
      // Empty stream - save recording with no chunks
      save_streaming_recording(state, [])
      yielder.Done
    }
    Error(error_reason) -> {
      // Error on first chunk - don't record, just pass through error
      yielder.Next(Error(error_reason), state)
    }
  }
}

fn handle_recording_yielder_next(
  owner: d.Dynamic,
  state: RecordingYielderState,
) -> yielder.Step(Result(bytes_tree.BytesTree, String), RecordingYielderState) {
  let now = get_time_ms()

  case internal.receive_next(owner, state.timeout_ms) {
    Ok(option.Some(bin)) -> {
      // Calculate delay since last chunk
      let delay = case state.last_chunk_time {
        Some(last_time) -> now - last_time
        None -> 0
      }

      // Record the chunk
      let chunk = recording.Chunk(data: bin, delay_ms: delay)
      let new_state =
        RecordingYielderState(
          ..state,
          chunks: [chunk, ..state.chunks],
          last_chunk_time: Some(now),
        )
      yielder.Next(Ok(bytes_tree.from_bit_array(bin)), new_state)
    }
    Ok(option.None) -> {
      // Stream finished - save recording
      save_streaming_recording(state, state.chunks)
      yielder.Done
    }
    Error(error_reason) -> {
      // Stream error - save what we have so far
      save_streaming_recording(state, state.chunks)
      yielder.Next(Error(error_reason), state)
    }
  }
}

fn save_streaming_recording(
  state: RecordingYielderState,
  chunks: List(recording.Chunk),
) -> Nil {
  // Reverse chunks to get correct order (we prepended them)
  let ordered_chunks = list.reverse(chunks)

  let response =
    recording.StreamingResponse(
      status: 200,
      // TODO: capture actual status and headers
      headers: [],
      chunks: ordered_chunks,
    )

  let rec =
    recording.Recording(request: state.recorded_request, response: response)

  recorder.add_recording(state.recorder, rec)
}

/// Start a message-based streaming HTTP request (OTP compatible)
///
/// Sends an HTTP request and returns a request ID immediately. httpc sends
/// stream messages directly to your process mailbox. Use this for:
///
/// - **OTP actors handling multiple concurrent streams**
/// - **Long-lived connections that need cancellation**
/// - **Integration with OTP supervisors and selectors**
///
/// For simple sequential streaming, use `stream_yielder()` instead.
///
/// ## Message Flow
///
/// Messages are sent to your process mailbox automatically:
/// 1. `StreamStart(request_id, headers)` - Headers received
/// 2. `Chunk(request_id, data)` - Zero or more data chunks
/// 3. `StreamEnd(request_id, headers)` or `StreamError(request_id, reason)` - Done
///
/// ## Parameters
///
/// - `req`: The configured HTTP request
///
/// ## Returns
///
/// - `Ok(RequestId)`: Stream started, messages will arrive in your mailbox
/// - `Error(String)`: Failed to start the stream
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{
///   type StreamMessage, Chunk, StreamEnd, StreamError, StreamStart,
///   select_stream_messages
/// }
/// import gleam/otp/actor.{continue}
/// import gleam/erlang/process.{new_selector}
///
/// pub type Message {
///   HttpStream(StreamMessage)
/// }
///
/// fn handle_message(msg: Message, state: State) {
///   case msg {
///     HttpStream(stream_msg) -> {
///       case stream_msg {
///         Chunk(req_id, data) -> process_chunk(data, state)
///         StreamEnd(req_id, _) -> cleanup(req_id, state)
///         StreamError(req_id, reason) -> handle_error(req_id, reason, state)
///         StreamStart(_, _) -> continue(state)
///       }
///     }
///   }
/// }
///
/// fn init_selector() {
///   new_selector()
///   |> select_stream_messages(HttpStream)
/// }
/// ```
pub fn stream_messages(
  client_request: ClientRequest,
) -> Result(RequestId, String) {
  // Check for recorder - if in Record mode, check playback first
  case client_request.recorder {
    option.Some(recorder_instance) ->
      stream_messages_with_recorder(client_request, recorder_instance)
    option.None -> stream_messages_without_recorder(client_request)
  }
}

fn stream_messages_with_recorder(
  client_request: ClientRequest,
  recorder_instance: recorder.Recorder,
) -> Result(RequestId, String) {
  let recorded_request = client_request_to_recorded_request(client_request)

  case recorder.find_recording(recorder_instance, recorded_request) {
    option.Some(_recording) ->
      // Found recording - message streaming doesn't support playback
      // because we can't inject messages into user's mailbox
      Error(
        "Message-based streaming does not support playback mode. Use stream_yielder() instead.",
      )
    option.None ->
      send_stream_messages_to_httpc(
        client_request,
        option.Some(recorder_instance),
        recorded_request,
      )
  }
}

fn stream_messages_without_recorder(
  client_request: ClientRequest,
) -> Result(RequestId, String) {
  let recorded_request = client_request_to_recorded_request(client_request)
  send_stream_messages_to_httpc(client_request, option.None, recorded_request)
}

fn send_stream_messages_to_httpc(
  client_request: ClientRequest,
  recorder_option: Option(recorder.Recorder),
  recorded_request: recording.RecordedRequest,
) -> Result(RequestId, String) {
  let http_request = to_http_request(client_request)
  let url = build_url(http_request)
  let method_atom = internal.atomize_method(http_request.method)
  let body = <<http_request.body:utf8>>
  let caller_process = process.self()
  let timeout_value = resolve_timeout(client_request)

  let start_result =
    internal.start_stream_messages(
      method_atom,
      url,
      http_request.headers,
      body,
      caller_process,
      timeout_value,
    )

  case parse_stream_start_result(start_result) {
    Ok(request_id) -> {
      record_message_stream_if_needed(
        request_id,
        recorder_option,
        recorded_request,
      )
      Ok(request_id)
    }
    Error(error_reason) -> Error(error_reason)
  }
}

fn record_message_stream_if_needed(
  request_id: RequestId,
  recorder_option: Option(recorder.Recorder),
  recorded_request: recording.RecordedRequest,
) -> Nil {
  case recorder_option {
    option.Some(recorder_instance) -> {
      case recorder.is_record_mode(recorder_instance) {
        True ->
          store_message_stream_recorder(
            request_id,
            recorder_instance,
            recorded_request,
          )
        False -> Nil
      }
    }
    option.None -> Nil
  }
}

fn build_url(request: request.Request(String)) -> String {
  let port_string = case request.port {
    option.Some(port) -> ":" <> int.to_string(port)
    option.None -> ""
  }
  http.scheme_to_string(request.scheme)
  <> "://"
  <> request.host
  <> port_string
  <> request.path
}

fn parse_stream_start_result(result: d.Dynamic) -> Result(RequestId, String) {
  let tag_result = d.run(result, d.at([0], d.dynamic))
  case tag_result {
    Ok(tag_dyn) -> parse_stream_start_tag(tag_dyn, result)
    Error(decode_errors) ->
      Error("Failed to parse httpc response: " <> string.inspect(decode_errors))
  }
}

fn parse_stream_start_tag(
  tag_dyn: d.Dynamic,
  result: d.Dynamic,
) -> Result(RequestId, String) {
  let tag = atom.cast_from_dynamic(tag_dyn) |> atom.to_string
  case tag {
    "ok" -> extract_request_id(result)
    "error" -> extract_error_reason(result)
    _ -> Error("Unknown response from httpc")
  }
}

fn extract_request_id(result: d.Dynamic) -> Result(RequestId, String) {
  let id_result = d.run(result, d.at([1], d.string))
  case id_result {
    Ok(id_string) -> Ok(RequestId(id: id_string))
    Error(decode_errors) ->
      Error("Failed to extract request ID: " <> string.inspect(decode_errors))
  }
}

fn extract_error_reason(result: d.Dynamic) -> Result(RequestId, String) {
  let reason_result = d.run(result, d.at([1], d.dynamic))
  case reason_result {
    Ok(reason_dyn) -> {
      let reason = string.inspect(reason_dyn)
      Error("Failed to start stream: " <> reason)
    }
    Error(decode_error) -> {
      Error(
        "Failed to start stream (decode error: "
        <> string.inspect(decode_error)
        <> ")",
      )
    }
  }
}

/// Add stream message handling to an OTP selector
///
/// Integrates HTTP stream messages into your OTP actor's selector. This allows
/// you to handle HTTP streams alongside other messages in your actor.
///
/// The mapper function converts `StreamMessage` to your actor's message type.
///
/// ## Parameters
///
/// - `selector`: Your existing selector
/// - `mapper`: Function to wrap `StreamMessage` in your message type
///
/// ## Returns
///
/// Updated selector that handles stream messages
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{type StreamMessage, select_stream_messages}
/// import gleam/erlang/process.{type Selector, new_selector, selecting}
///
/// pub type Message {
///   HttpStream(StreamMessage)
///   OtherMessage(String)
/// }
///
/// fn build_selector() -> Selector(Message) {
///   new_selector()
///   |> select_stream_messages(HttpStream)
///   |> selecting(some_subject, OtherMessage)
/// }
/// ```
pub fn select_stream_messages(
  selector: process.Selector(msg),
  mapper: fn(StreamMessage) -> msg,
) -> process.Selector(msg) {
  selector
  |> process.select_record(
    tag: atom.create("http"),
    fields: 1,
    mapping: create_selector_mapper(mapper),
  )
}

fn create_selector_mapper(
  mapper: fn(StreamMessage) -> msg,
) -> fn(d.Dynamic) -> msg {
  // process.select_record requires a callback of type fn(Dynamic) -> msg.
  // This small helper exists to adapt that interface while keeping the
  // higher-level mapper explicit and testable.
  apply_mapper_to_dynamic(_, mapper)
}

fn apply_mapper_to_dynamic(
  dyn: d.Dynamic,
  mapper: fn(StreamMessage) -> msg,
) -> msg {
  // Erlang does the heavy lifting: converts raw httpc messages to clean format
  // We just decode the simple {Tag, RequestId, Data} tuple
  let simplified = internal.decode_stream_message_for_selector(dyn)
  let stream_msg = decode_simplified_message(simplified)

  // Record the message if this stream has a recorder
  record_stream_message(stream_msg)

  mapper(stream_msg)
}

fn decode_simplified_message(dyn: d.Dynamic) -> StreamMessage {
  // Decode the clean {Tag, StringId, Data} tuple from Erlang
  let tag_result = d.run(dyn, d.at([0], d.dynamic))
  let req_id_result = d.run(dyn, d.at([1], d.string))
  let data_result = d.run(dyn, d.at([2], d.dynamic))

  case tag_result {
    Ok(tag_dyn) -> decode_with_tag(tag_dyn, req_id_result, data_result)
    Error(decode_error) -> handle_tag_decode_error(decode_error, req_id_result)
  }
}

fn handle_tag_decode_error(
  decode_error: List(d.DecodeError),
  req_id_result: Result(String, List(d.DecodeError)),
) -> StreamMessage {
  let error_msg =
    "Internal error: Failed to decode stream message tag: "
    <> string.inspect(decode_error)
  case req_id_result {
    Ok(req_id_string) -> {
      let req_id = RequestId(id: req_id_string)
      StreamError(req_id, error_msg)
    }
    Error(req_id_error) -> {
      let full_error_msg =
        error_msg
        <> " (also failed to decode request ID: "
        <> string.inspect(req_id_error)
        <> ")"
      DecodeError(full_error_msg)
    }
  }
}

fn decode_with_tag(
  tag_dyn: d.Dynamic,
  req_id_result: Result(String, List(d.DecodeError)),
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  let tag = atom.cast_from_dynamic(tag_dyn) |> atom.to_string
  case req_id_result {
    Ok(req_id_string) -> {
      let req_id = RequestId(id: req_id_string)
      decode_by_tag(tag, req_id, data_result)
    }
    Error(decode_error) -> {
      // Can't decode request ID - return DecodeError
      let error_msg =
        "Internal error: Failed to decode request ID from stream message: "
        <> string.inspect(decode_error)
      DecodeError(error_msg)
    }
  }
}

fn decode_by_tag(
  tag: String,
  req_id: RequestId,
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  case tag {
    "stream_start" -> decode_stream_start(req_id, data_result)
    "chunk" -> decode_chunk(req_id, data_result)
    "stream_end" -> decode_stream_end(req_id, data_result)
    "stream_error" -> decode_stream_error(req_id, data_result)
    _ ->
      StreamError(req_id, "Internal error: Unknown stream message tag: " <> tag)
  }
}

fn decode_stream_start(
  req_id: RequestId,
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  case data_result {
    Ok(headers_dyn) -> decode_stream_start_headers(req_id, headers_dyn)
    Error(decode_error) -> {
      let error_msg =
        "Failed to get headers data in StreamStart: "
        <> string.inspect(decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_stream_start_headers(
  req_id: RequestId,
  headers_dyn: d.Dynamic,
) -> StreamMessage {
  case decode_headers(headers_dyn) {
    Ok(headers) -> StreamStart(req_id, headers)
    Error(header_decode_error) -> {
      let error_msg =
        "Failed to decode headers in StreamStart: "
        <> string.inspect(header_decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_chunk(
  req_id: RequestId,
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  case data_result {
    Ok(data_dyn) -> decode_chunk_data(req_id, data_dyn)
    Error(decode_error) -> {
      let error_msg =
        "Internal error: Failed to get chunk data: "
        <> string.inspect(decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_chunk_data(req_id: RequestId, data_dyn: d.Dynamic) -> StreamMessage {
  case d.run(data_dyn, d.bit_array) {
    Ok(data) -> Chunk(req_id, data)
    Error(decode_error) -> {
      let error_msg =
        "Internal error: Failed to decode chunk data: "
        <> string.inspect(decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_stream_end(
  req_id: RequestId,
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  case data_result {
    Ok(headers_dyn) -> decode_stream_end_headers(req_id, headers_dyn)
    Error(decode_error) -> {
      let error_msg =
        "Failed to get trailing headers data in StreamEnd: "
        <> string.inspect(decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_stream_end_headers(
  req_id: RequestId,
  headers_dyn: d.Dynamic,
) -> StreamMessage {
  case decode_headers(headers_dyn) {
    Ok(headers) -> StreamEnd(req_id, headers)
    Error(header_decode_error) -> {
      let error_msg =
        "Failed to decode trailing headers in StreamEnd: "
        <> string.inspect(header_decode_error)
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_stream_error(
  req_id: RequestId,
  data_result: Result(d.Dynamic, List(d.DecodeError)),
) -> StreamMessage {
  case data_result {
    Ok(reason_dyn) -> decode_error_reason(req_id, reason_dyn)
    Error(decode_error) -> {
      let error_msg =
        "Stream error (failed to decode error reason: "
        <> string.inspect(decode_error)
        <> ")"
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_error_reason(
  req_id: RequestId,
  reason_dyn: d.Dynamic,
) -> StreamMessage {
  case d.run(reason_dyn, d.string) {
    Ok(reason) -> StreamError(req_id, reason)
    Error(decode_error) -> {
      let error_msg =
        "Stream error (failed to decode error string: "
        <> string.inspect(decode_error)
        <> ")"
      StreamError(req_id, error_msg)
    }
  }
}

fn decode_headers(
  dyn: d.Dynamic,
) -> Result(List(#(String, String)), List(d.DecodeError)) {
  // Headers are normalized to string tuples by the Erlang shim
  let header_decoder =
    d.at([0], d.string)
    |> d.then(decode_header_value)

  d.run(dyn, d.list(header_decoder))
}

fn decode_header_value(name: String) -> d.Decoder(#(String, String)) {
  d.at([1], d.string)
  |> d.map(pair_with_name(_, name))
}

fn pair_with_name(value: String, name: String) -> #(String, String) {
  #(name, value)
}

/// Cancel an active streaming request
///
/// Cancels an HTTP stream that was started with `stream_messages()`.
/// After cancellation, no more messages will be sent to your process.
///
/// ## Parameters
///
/// - `request_id`: The request ID returned from `stream_messages()`
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/client.{host, stream_messages, cancel_stream}
///
/// let assert Ok(req_id) = client.new
///   |> host("api.example.com")
///   |> stream_messages()
///
/// // Later, cancel the stream
/// cancel_stream(req_id)
/// ```
pub fn cancel_stream(request_id: RequestId) -> Nil {
  let RequestId(id) = request_id
  internal.cancel_stream_by_string(id)
}

// ============================================================================
// Message-Based Streaming Recorder (Internal - ETS Storage)
// ============================================================================

type MessageStreamRecorderState {
  MessageStreamRecorderState(
    recorder: recorder.Recorder,
    recorded_request: recording.RecordedRequest,
    chunks: List(recording.Chunk),
    last_chunk_time: Option(Int),
  )
}

// ETS table name for recorder state
const recorder_table_name = "dream_http_client_stream_recorders"

// Ensure ETS table exists (idempotent)
fn ensure_recorder_table() -> Nil {
  case ets_table_exists(recorder_table_name) {
    True -> Nil
    False -> {
      ets_new(recorder_table_name, [
        atom.create("set"),
        atom.create("public"),
        atom.create("named_table"),
      ])
      Nil
    }
  }
}

@external(erlang, "dream_httpc_shim", "ets_table_exists")
fn ets_table_exists(name: String) -> Bool

@external(erlang, "dream_httpc_shim", "ets_new")
fn ets_new(name: String, options: List(atom.Atom)) -> d.Dynamic

@external(erlang, "dream_httpc_shim", "ets_insert")
fn ets_insert(
  table: String,
  key: String,
  recorder: recorder.Recorder,
  recorded_request: recording.RecordedRequest,
  chunks: List(recording.Chunk),
  last_chunk_time: Option(Int),
) -> Nil

@external(erlang, "dream_httpc_shim", "ets_lookup")
fn ets_lookup(table: String, key: String) -> Option(MessageStreamRecorderState)

@external(erlang, "dream_httpc_shim", "ets_delete")
fn ets_delete(table: String, key: String) -> Bool

fn store_message_stream_recorder(
  request_id: RequestId,
  rec: recorder.Recorder,
  recorded_req: recording.RecordedRequest,
) -> Nil {
  ensure_recorder_table()
  let RequestId(id) = request_id
  ets_insert(recorder_table_name, id, rec, recorded_req, [], None)
}

fn get_message_stream_recorder(
  request_id: RequestId,
) -> Option(MessageStreamRecorderState) {
  let RequestId(id) = request_id
  ets_lookup(recorder_table_name, id)
}

fn update_message_stream_recorder(
  request_id: RequestId,
  state: MessageStreamRecorderState,
) -> Nil {
  let RequestId(id) = request_id
  ets_insert(
    recorder_table_name,
    id,
    state.recorder,
    state.recorded_request,
    state.chunks,
    state.last_chunk_time,
  )
}

fn remove_message_stream_recorder(request_id: RequestId) -> Nil {
  let RequestId(id) = request_id
  ets_delete(recorder_table_name, id)
  Nil
}

fn record_stream_message(message: StreamMessage) -> Nil {
  case message {
    Chunk(request_id, data) -> {
      case get_message_stream_recorder(request_id) {
        option.Some(state) -> {
          let now = get_time_ms()
          let delay = case state.last_chunk_time {
            Some(last_time) -> now - last_time
            None -> 0
          }

          let chunk = recording.Chunk(data: data, delay_ms: delay)
          let new_state =
            MessageStreamRecorderState(
              recorder: state.recorder,
              recorded_request: state.recorded_request,
              chunks: [chunk, ..state.chunks],
              last_chunk_time: Some(now),
            )
          update_message_stream_recorder(request_id, new_state)
        }
        option.None -> Nil
      }
    }
    StreamEnd(request_id, _headers) -> {
      case get_message_stream_recorder(request_id) {
        option.Some(state) -> {
          finish_message_stream_recording(request_id, state)
        }
        option.None -> Nil
      }
    }
    StreamError(request_id, error_reason) -> {
      let RequestId(request_id_string) = request_id
      io.println_error(
        "HTTP stream error while recording messages for request "
        <> request_id_string
        <> ": "
        <> error_reason,
      )
      case get_message_stream_recorder(request_id) {
        option.Some(state) -> {
          finish_message_stream_recording(request_id, state)
        }
        option.None -> Nil
      }
    }
    StreamStart(_request_id, _headers) -> Nil
    DecodeError(error_reason) -> {
      // DecodeError indicates a serious FFI problem at the FFI boundary.
      io.println_error(
        "Internal DecodeError in HTTP stream message recorder: " <> error_reason,
      )
      Nil
    }
  }
}

fn finish_message_stream_recording(
  request_id: RequestId,
  state: MessageStreamRecorderState,
) -> Nil {
  let ordered_chunks = list.reverse(state.chunks)

  let response =
    recording.StreamingResponse(
      status: 200,
      // TODO: capture actual status and headers from StreamStart
      headers: [],
      chunks: ordered_chunks,
    )

  let rec =
    recording.Recording(request: state.recorded_request, response: response)

  recorder.add_recording(state.recorder, rec)
  remove_message_stream_recorder(request_id)
}
