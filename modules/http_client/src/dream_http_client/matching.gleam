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
/// This ignores headers and body, which is practical for most use cases
/// since headers often contain timestamps, auth tokens, etc., and bodies
/// may contain dynamic IDs.
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
/// Creates a string signature from the request based on the matching
/// configuration. This signature is used as a key to look up recordings.
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
