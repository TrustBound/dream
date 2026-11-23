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
  type Method, type Request, Connect, Delete, Get, Head, Http, Http1, Https,
  Options, Other, Patch, Post, Put, Request, Text, Trace,
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
import mist.{type Connection, type IpAddress, get_connection_info}

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
/// ### Generate a request ID <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_request_id.gleam#L5-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn new_request_id() -> String {
///   let request_id = generate_request_id()
///   // Returns something like: "//erl(<0.123.0>)"
///   request_id
/// }
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
/// - `mist_request`: The original Mist request with Connection
///
/// ## Returns
///
/// A tuple of `#(Dream Request, request_id)` where:
/// - Dream Request contains all HTTP metadata (empty body: `Text("")`)
/// - request_id is a unique identifier for this request
///
/// ## Example
///
/// ### Read the request metadata <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_convert_metadata.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{method_to_string}
/// import dream/servers/mist/request as mist_request
/// import gleam/bytes_tree
/// import gleam/http/request as http_request
/// import gleam/http/response as http_response
/// import mist.{type Connection, type ResponseData}
///
/// pub fn describe(
///   request: http_request.Request(Connection),
/// ) -> http_response.Response(ResponseData) {
///   // The Dream request has the method, path, query and headers, with an
///   // empty body
///   let #(dream_request, _request_id) = mist_request.convert_metadata(request)
///   // GET /users?page=2 gives "GET /users?page=2"
///   let description =
///     method_to_string(dream_request.method)
///     <> " "
///     <> dream_request.path
///     <> "?"
///     <> dream_request.query
///   http_response.new(200)
///   |> http_response.set_body(mist.Bytes(bytes_tree.from_string(description)))
/// }
/// ```
pub fn convert_metadata(
  mist_request: http_request.Request(Connection),
) -> #(Request, String) {
  // Generate request_id for context creation
  let request_id = generate_request_id()

  // Convert HTTP method
  let method = convert_method(mist_request.method)

  // Convert protocol
  let protocol = case mist_request.scheme {
    HttpScheme -> Http
    HttpHttps -> Https
  }

  // Convert HTTP version (defaulting to HTTP/1.1 for now)
  let version = Http1

  // Get path and query
  let path = mist_request.path
  let query = option.unwrap(mist_request.query, "")

  // Convert headers
  let headers = list.map(mist_request.headers, convert_header)

  // Parse cookies from headers
  let cookies = dream.parse_cookies_from_headers(headers)

  // Get content type
  let content_type =
    list.key_find(mist_request.headers, "content-type")
    |> option.from_result

  // Get content length
  let content_length =
    list.key_find(mist_request.headers, "content-length")
    |> result.try(int.parse)
    |> option.from_result

  // Get client info
  let connection_info = get_connection_info(mist_request.body)
  let remote_address = case connection_info {
    Ok(connection_info) -> {
      let ip_address: IpAddress = connection_info.ip_address
      format_ip_address(ip_address) |> option.Some
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
      host: option.Some(mist_request.host),
      port: mist_request.port,
      remote_address: remote_address,
      body: Text(""),
      headers: headers,
      cookies: cookies,
      content_type: content_type,
      content_length: content_length,
    )

  #(request, request_id)
}

/// Convert HTTP method from gleam/http format to Dream format
///
/// Each method keeps its meaning. A method with no own constructor becomes
/// `Other` with its name exactly as the client sent it. The server gives a
/// standard name only in upper case: a lower-case `get` arrives as
/// `HttpOther("get")` and stays `Other("get")`, because RFC 9110 section 9.1
/// makes method names case-sensitive.
fn convert_method(http_method: HttpMethod) -> Method {
  case http_method {
    HttpGet -> Get
    HttpPost -> Post
    HttpPut -> Put
    HttpDelete -> Delete
    HttpPatch -> Patch
    HttpOptions -> Options
    HttpHead -> Head
    HttpConnect -> Connect
    HttpTrace -> Trace
    HttpOther(name) -> Other(name)
  }
}

fn convert_header(header: #(String, String)) -> Header {
  Header(name: header.0, value: header.1)
}

/// Writes a client address as text: dotted decimal for IPv4, and the RFC 5952
/// form for IPv6 (lower case, no leading zeros, the longest run of two or
/// more zero groups written as `::`).
///
/// An IPv4 client of an IPv6 socket arrives here as IPv4, because the socket
/// layer gives an IPv4-mapped peer address (`::ffff:a.b.c.d`) as the IPv4
/// address.
@internal
pub fn format_ip_address(ip_address: IpAddress) -> String {
  mist.ip_address_to_string(ip_address)
}
