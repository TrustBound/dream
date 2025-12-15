//// Request matching logic
////
//// Provides helpers for building stable request match keys.
////
//// A match key is a function that converts a `recording.RecordedRequest` into a
//// string. Requests that produce the same key are considered equivalent for
//// recording lookup and playback.
////
//// ## Keys + transformers
////
//// For many use cases, a key alone is enough. For cases like “ignore one query
//// parameter” or “scrub secrets but still match”, pair a key with a
//// `recorder.request_transformer(...)` so both matching and persistence see the same
//// normalized request.

import dream_http_client/recording
import gleam/http
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string

/// A function that produces a stable match key for a request.
pub type MatchKey =
  fn(recording.RecordedRequest) -> String

/// Create a request key function from simple include/exclude flags.
///
/// This is intended for the most common matching policies. For more advanced
/// matching (ignore specific headers, normalize paths, drop query params, etc.)
/// compose a `recorder.request_transformer(...)` with a custom key function.
///
/// ## Parameters
///
/// - `method`: Include the HTTP method in the key
/// - `url`: Include the full URL (scheme + host + port + path + query) in the key
/// - `headers`: Include request headers in the key (sorted by header name)
/// - `body`: Include the request body in the key
///
/// ## Returns
///
/// A `MatchKey` function.
///
/// ## Example
///
/// ```gleam
/// import dream_http_client/matching
/// import dream_http_client/recorder
/// import dream_http_client/recording
/// import dream_http_client/recorder.{directory, key, mode, request_transformer, start}
/// import gleam/list
///
/// // Build a key that ignores headers and body.
/// let key =
///   matching.request_key(method: True, url: True, headers: False, body: False)
///
/// // Drop Authorization before keying and before writing to disk.
/// fn drop_auth(req: recording.RecordedRequest) -> recording.RecordedRequest {
///   let headers =
///     req.headers
///     |> list.filter(fn(h) { h.0 != "Authorization" })
///   recording.RecordedRequest(..req, headers: headers)
/// }
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> mode("record")
///   |> directory("mocks/api")
///   |> key(key)
///   |> request_transformer(drop_auth)
///   |> start()
/// ```
pub fn request_key(
  method method: Bool,
  url url: Bool,
  headers headers: Bool,
  body body: Bool,
) -> MatchKey {
  fn(request: recording.RecordedRequest) {
    let method_str = case method {
      True -> method_to_string(request.method)
      False -> ""
    }

    let url_str = case url {
      True -> build_url(request)
      False -> ""
    }

    let headers_str = case headers {
      True -> headers_to_string(request.headers)
      False -> ""
    }

    let body_str = case body {
      True -> request.body
      False -> ""
    }

    method_str <> url_str <> headers_str <> body_str
  }
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
