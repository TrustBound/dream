//// Request conversion from Mist to Dream format
////
//// This module provides functions to convert Mist HTTP requests
//// to Dream request format, including method, header, and cookie conversion.
////
//// This is an internal module used by the Dream server implementation.
//// Most applications won't need to use this directly.

import dream/dream
import dream/http/header.{type Header, Header}
import dream/http/request.{
  type Method, type Request, Delete, Get, Head, Http, Http1, Https, Options,
  Patch, Post, Put, Request,
}
import gleam/erlang/process
import gleam/http.{
  type Method as HttpMethod, Connect as HttpConnect, Delete as HttpDelete,
  Get as HttpGet, Head as HttpHead, Http as HttpScheme, Https as HttpHttps,
  Options as HttpOptions, Other as HttpOther, Patch as HttpPatch,
  Post as HttpPost, Put as HttpPut, Trace as HttpTrace,
}
import gleam/http/request as http_request
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mist.{type Connection, type IpAddress, get_client_info}

/// Generate a simple request ID
///
/// Creates a request ID using the current process ID.
/// This provides a unique identifier for each request that can be used
/// for logging, tracing, and debugging.
///
/// In production applications, you may want to use UUID or a more
/// sophisticated ID generation strategy.
///
/// ## Example
///
/// ```gleam
/// let request_id = generate_request_id()
/// // Returns something like: "#PID<0.123.0>"
/// ```
pub fn generate_request_id() -> String {
  // Simple ID generation - in production you might want to use UUID
  let process_id = process.self()
  let process_id_string = string.inspect(process_id)
  process_id_string
}

/// Convert Mist request metadata to Dream request format
///
/// Converts a Mist HTTP request (headers, method, path, etc.) to Dream's
/// unified request format, but leaves the body empty. The body handling
/// is deferred until after route matching to support streaming.
///
/// ## Parameters
///
/// - `mist_req`: The original Mist request with Connection
///
/// ## Returns
///
/// A tuple of `#(Dream Request, request_id)` where:
/// - Dream Request contains all HTTP metadata (empty body)
/// - request_id is a unique identifier for this request
pub fn convert_metadata(
  mist_req: http_request.Request(Connection),
) -> #(Request, String) {
  // Generate request_id for context creation
  let request_id = generate_request_id()

  // Convert HTTP method
  let method = convert_method(mist_req.method)

  // Convert protocol
  let protocol = case mist_req.scheme {
    HttpScheme -> Http
    HttpHttps -> Https
  }

  // Convert HTTP version (defaulting to HTTP/1.1 for now)
  let version = Http1

  // Get path and query
  let path = mist_req.path
  let query = option.unwrap(mist_req.query, "")

  // Convert headers
  let headers = list.map(mist_req.headers, convert_header)

  // Parse cookies from headers
  let cookies = dream.parse_cookies_from_headers(headers)

  // Get content type
  let content_type =
    list.key_find(mist_req.headers, "content-type")
    |> option.from_result

  // Get content length
  let content_length =
    list.key_find(mist_req.headers, "content-length")
    |> result.try(int.parse)
    |> option.from_result

  // Get client info
  let client_info = get_client_info(mist_req.body)
  let remote_address = case client_info {
    Ok(info) -> {
      let ip_address: IpAddress = info.ip_address
      format_ip_address_value(ip_address) |> option.Some
    }
    Error(_) -> option.None
  }

  let request =
    Request(
      method: method,
      protocol: protocol,
      version: version,
      path: path,
      query: query,
      params: [],
      host: option.Some(mist_req.host),
      port: mist_req.port,
      remote_address: remote_address,
      body: "",
      stream: option.None,
      headers: headers,
      cookies: cookies,
      content_type: content_type,
      content_length: content_length,
    )

  #(request, request_id)
}

/// Convert HTTP method from gleam/http format to Dream format
fn convert_method(http_method: HttpMethod) -> Method {
  case http_method {
    HttpGet -> Get
    HttpPost -> Post
    HttpPut -> Put
    HttpDelete -> Delete
    HttpPatch -> Patch
    HttpOptions -> Options
    HttpHead -> Head
    HttpOther(_) -> Get
    // Fallback for unknown methods
    HttpConnect -> Get
    // Fallback
    HttpTrace -> Get
    // Fallback
  }
}

fn convert_header(header: #(String, String)) -> Header {
  Header(name: header.0, value: header.1)
}

fn format_ip_address_value(ip_address: IpAddress) -> String {
  case ip_address {
    mist.IpV4(a, b, c, d) ->
      string.join(
        [
          int.to_string(a),
          ".",
          int.to_string(b),
          ".",
          int.to_string(c),
          ".",
          int.to_string(d),
        ],
        "",
      )
    mist.IpV6(..) -> "::1"
    // Simplified for IPv6
  }
}
