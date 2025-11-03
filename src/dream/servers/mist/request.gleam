//// Request conversion from Mist to Dream format
////
//// This module provides functions to convert Mist HTTP requests
//// to Dream request format, including method, header, and cookie conversion.

import dream/core/dream
import dream/core/http/transaction
import gleam/bit_array
import gleam/http.{
  type Method as HttpMethod, Connect as HttpConnect, Delete as HttpDelete,
  Get as HttpGet, Head as HttpHead, Http as HttpScheme, Https as HttpHttps,
  Options as HttpOptions, Other as HttpOther, Patch as HttpPatch,
  Post as HttpPost, Put as HttpPut, Trace as HttpTrace,
}
import gleam/http/request.{type Request as HttpRequest}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mist.{type Connection, get_client_info}

/// Convert mist Request to Dream Request
pub fn convert(
  mist_req: HttpRequest(Connection),
  req_with_body: HttpRequest(BitArray),
) -> transaction.Request {
  // Convert HTTP method
  let method = convert_method(mist_req.method)

  // Convert protocol
  let protocol = case mist_req.scheme {
    HttpScheme -> transaction.Http
    HttpHttps -> transaction.Https
  }

  // Convert HTTP version (defaulting to HTTP/1.1 for now)
  let version = transaction.Http1

  // Get path and query
  let path = mist_req.path
  let query = option.unwrap(mist_req.query, "")

  // Convert headers
  let headers =
    list.map(mist_req.headers, fn(header) {
      transaction.Header(name: header.0, value: header.1)
    })

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

  // Convert body to string
  let body_string =
    bit_array.to_string(req_with_body.body)
    |> result.unwrap("")

  // Get client info
  let client_info = get_client_info(mist_req.body)
  let remote_address =
    result.map(client_info, fn(info) {
      case info.ip_address {
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
    })
    |> option.from_result

  transaction.Request(
    method: method,
    protocol: protocol,
    version: version,
    path: path,
    query: query,
    params: [],
    host: option.Some(mist_req.host),
    port: mist_req.port,
    remote_address: remote_address,
    body: body_string,
    headers: headers,
    cookies: cookies,
    content_type: content_type,
    content_length: content_length,
  )
}

/// Convert HTTP method from gleam/http format to Dream format
fn convert_method(http_method: HttpMethod) -> transaction.Method {
  case http_method {
    HttpGet -> transaction.Get
    HttpPost -> transaction.Post
    HttpPut -> transaction.Put
    HttpDelete -> transaction.Delete
    HttpPatch -> transaction.Patch
    HttpOptions -> transaction.Options
    HttpHead -> transaction.Head
    HttpOther(_) -> transaction.Get
    // Fallback for unknown methods
    HttpConnect -> transaction.Get
    // Fallback
    HttpTrace -> transaction.Get
    // Fallback
  }
}
