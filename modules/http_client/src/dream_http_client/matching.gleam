//// Request matching logic
////
//// Determines if a request matches a recorded request based on configurable
//// matching criteria (method, URL, headers, body).

import dream_http_client/recording
import gleam/http
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string

/// Configuration for request matching
///
/// Determines which parts of an HTTP request are used when matching incoming
/// requests against recorded ones. This allows you to ignore dynamic parts
/// like timestamps, auth tokens, or request IDs while still matching on
/// meaningful request characteristics.
///
/// ## Fields
///
/// - `match_method`: Whether to match on HTTP method (GET, POST, etc.)
/// - `match_url`: Whether to match on full URL (scheme + host + port + path + query)
/// - `match_headers`: Whether to match on request headers
/// - `match_body`: Whether to match on request body
///
/// ## Examples
///
/// ```gleam
/// // Match on method and URL only (ignores headers and body)
/// let config = matching.MatchingConfig(
///   match_method: True,
///   match_url: True,
///   match_headers: False,  // Ignore auth tokens, timestamps, etc.
///   match_body: False,     // Ignore dynamic IDs in body
/// )
///
/// // Match on everything (strict matching)
/// let strict_config = matching.MatchingConfig(
///   match_method: True,
///   match_url: True,
///   match_headers: True,
///   match_body: True,
/// )
/// ```
///
/// ## Notes
///
/// - Use `match_url_only()` for the recommended default configuration
/// - Headers often contain timestamps, auth tokens, or request IDs that change between requests
/// - Bodies may contain dynamic IDs or timestamps that prevent matching
/// - URL matching includes scheme, host, port, path, and query string
pub type MatchingConfig {
  MatchingConfig(
    match_method: Bool,
    match_url: Bool,
    // scheme + host + port + path + query
    match_headers: Bool,
    match_body: Bool,
  )
}

/// Default matching configuration: match on method and URL only
///
/// Creates a `MatchingConfig` that matches requests based on HTTP method and
/// full URL (scheme, host, port, path, query), while ignoring headers and body.
/// This is the recommended configuration for most use cases.
///
/// ## Why This Default?
///
/// Headers and bodies often contain dynamic values that change between requests:
/// - Headers: Authorization tokens, timestamps, request IDs, user agents
/// - Bodies: Dynamic IDs, timestamps, session tokens, nonces
///
/// By ignoring these, recordings remain stable and reusable across different
/// request contexts while still matching on the meaningful request characteristics.
///
/// ## Returns
///
/// A `MatchingConfig` with:
/// - `match_method: True`
/// - `match_url: True`
/// - `match_headers: False`
/// - `match_body: False`
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Playback(directory: "mocks"),
///   matching: matching.match_url_only(),  // Use default matching
/// )
/// ```
pub fn match_url_only() -> MatchingConfig {
  MatchingConfig(
    match_method: True,
    match_url: True,
    match_headers: False,
    match_body: False,
  )
}

/// Build a request signature for matching
///
/// Creates a string signature from a request based on the matching configuration.
/// This signature is used as a dictionary key to look up matching recordings.
/// Only the parts of the request specified in the config are included in the signature.
///
/// ## Parameters
///
/// - `request`: The request to build a signature for
/// - `config`: The matching configuration that determines which parts to include
///
/// ## Returns
///
/// A string signature that uniquely identifies the request based on the config.
/// Requests with the same signature will match each other.
///
/// ## Examples
///
/// ```gleam
/// let request = recording.RecordedRequest(
///   method: http.Get,
///   scheme: http.Https,
///   host: "api.example.com",
///   port: option.None,
///   path: "/users/123",
///   query: option.None,
///   headers: [#("Authorization", "Bearer token123")],
///   body: "",
/// )
///
/// let config = matching.match_url_only()
/// let signature = matching.build_signature(request, config)
/// // Signature includes method and URL, but not headers or body
/// ```
///
/// ## Notes
///
/// - This function is used internally by the recorder for matching
/// - The signature format is an implementation detail and may change
/// - Headers are sorted alphabetically when included for consistent matching
pub fn build_signature(
  request: recording.RecordedRequest,
  config: MatchingConfig,
) -> String {
  let method_str = case config.match_method {
    True -> method_to_string(request.method)
    False -> ""
  }

  let url_str = case config.match_url {
    True -> build_url(request)
    False -> ""
  }

  let headers_str = case config.match_headers {
    True -> headers_to_string(request.headers)
    False -> ""
  }

  let body_str = case config.match_body {
    True -> request.body
    False -> ""
  }

  method_str <> url_str <> headers_str <> body_str
}

/// Check if two requests match based on the configuration
///
/// Determines whether two requests are considered equivalent for the purposes
/// of recording playback. Uses the matching configuration to determine which
/// parts of the requests to compare.
///
/// ## Parameters
///
/// - `request1`: First request to compare
/// - `request2`: Second request to compare
/// - `config`: Matching configuration that determines which parts to compare
///
/// ## Returns
///
/// - `True`: Requests match according to the configuration
/// - `False`: Requests do not match
///
/// ## Examples
///
/// ```gleam
/// let request1 = recording.RecordedRequest(
///   method: http.Get,
///   scheme: http.Https,
///   host: "api.example.com",
///   port: option.None,
///   path: "/users",
///   query: option.None,
///   headers: [#("Authorization", "Bearer token1")],
///   body: "",
/// )
///
/// let request2 = recording.RecordedRequest(
///   method: http.Get,
///   scheme: http.Https,
///   host: "api.example.com",
///   port: option.None,
///   path: "/users",
///   query: option.None,
///   headers: [#("Authorization", "Bearer token2")],  // Different token
///   body: "",
/// )
///
/// let config = matching.match_url_only()  // Ignores headers
/// matching.requests_match(request1, request2, config)  // Returns True
/// ```
///
/// ## Notes
///
/// - This function is used internally by the recorder
/// - Matching is based on string signatures built from the config
/// - Headers are sorted before comparison for consistent results
pub fn requests_match(
  request1: recording.RecordedRequest,
  request2: recording.RecordedRequest,
  config: MatchingConfig,
) -> Bool {
  let sig1 = build_signature(request1, config)
  let sig2 = build_signature(request2, config)
  sig1 == sig2
}

fn method_to_string(method: http.Method) -> String {
  case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Patch -> "PATCH"
    http.Head -> "HEAD"
    http.Options -> "OPTIONS"
    http.Trace -> "TRACE"
    http.Connect -> "CONNECT"
    http.Other(s) -> string.uppercase(s)
  }
}

fn build_url(request: recording.RecordedRequest) -> String {
  let port_string = case request.port {
    option.Some(port) -> ":" <> int.to_string(port)
    option.None -> ""
  }
  let query_string = case request.query {
    option.Some(query) -> "?" <> query
    option.None -> ""
  }
  scheme_to_string(request.scheme)
  <> "://"
  <> request.host
  <> port_string
  <> request.path
  <> query_string
}

fn scheme_to_string(scheme: http.Scheme) -> String {
  case scheme {
    http.Http -> "http"
    http.Https -> "https"
  }
}

fn headers_to_string(headers: List(#(String, String))) -> String {
  // Sort headers for consistent matching
  let sorted = list.sort(headers, compare_header_names)
  let header_strings = list.map(sorted, format_header_pair)
  string.join(header_strings, "|")
}

fn compare_header_names(
  header1: #(String, String),
  header2: #(String, String),
) -> order.Order {
  string.compare(header1.0, header2.0)
}

fn format_header_pair(header: #(String, String)) -> String {
  header.0 <> ":" <> header.1
}
