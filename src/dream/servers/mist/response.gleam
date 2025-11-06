//// Response conversion from Dream to Mist format
////
//// This module provides functions to convert Dream HTTP responses
//// to Mist response format, including status code, header, and cookie conversion.

import dream/core/http/statuses
import dream/core/http/transaction
import gleam/bit_array
import gleam/bytes_tree
import gleam/http/response as http_response
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import mist.{type ResponseData, Bytes}

/// Convert Dream Response to mist Response
pub fn convert(
  dream_resp: transaction.Response,
) -> http_response.Response(ResponseData) {
  // Get status code from Status type
  let status_code = statuses.to_code(dream_resp.status)

  // Convert headers
  let headers = list.map(dream_resp.headers, convert_header_to_tuple)

  // Add cookie headers
  let headers_with_cookies =
    list.fold(dream_resp.cookies, headers, add_cookie_header)

  // Add content-type header if present
  let headers_with_content_type = case dream_resp.content_type {
    option.Some(ct) -> list.key_set(headers_with_cookies, "content-type", ct)
    option.None -> headers_with_cookies
  }

  // Convert body to BytesTree
  let body_bytes =
    bit_array.from_string(dream_resp.body)
    |> bytes_tree.from_bit_array

  let resp_with_body =
    http_response.new(status_code)
    |> http_response.set_body(Bytes(body_bytes))

  set_all_headers(headers_with_content_type, resp_with_body)
}

fn convert_header_to_tuple(header: transaction.Header) -> #(String, String) {
  #(
    string.lowercase(transaction.header_name(header)),
    transaction.header_value(header),
  )
}

fn add_cookie_header(
  acc: List(#(String, String)),
  cookie: transaction.Cookie,
) -> List(#(String, String)) {
  let cookie_header = format_cookie_header(cookie)
  [#("set-cookie", cookie_header), ..acc]
}

fn add_header(
  acc: http_response.Response(ResponseData),
  header: #(String, String),
) -> http_response.Response(ResponseData) {
  http_response.set_header(acc, header.0, header.1)
}

fn set_all_headers(
  headers: List(#(String, String)),
  resp: http_response.Response(ResponseData),
) -> http_response.Response(ResponseData) {
  list.fold(headers, resp, add_header)
}

/// Format a cookie for the Set-Cookie header
fn format_cookie_header(cookie: transaction.Cookie) -> String {
  let transaction.Cookie(
    name,
    value,
    expires,
    max_age,
    domain,
    path,
    secure,
    http_only,
    same_site,
  ) = cookie

  let base = name <> "=" <> value

  let with_expires = case expires {
    option.Some(exp) -> base <> "; Expires=" <> int.to_string(exp)
    option.None -> base
  }

  let with_max_age = case max_age {
    option.Some(age) -> with_expires <> "; Max-Age=" <> int.to_string(age)
    option.None -> with_expires
  }

  let with_domain = case domain {
    option.Some(dom) -> with_max_age <> "; Domain=" <> dom
    option.None -> with_max_age
  }

  let with_path = case path {
    option.Some(p) -> with_domain <> "; Path=" <> p
    option.None -> with_domain
  }

  let with_secure = case secure {
    True -> with_path <> "; Secure"
    False -> with_path
  }

  let with_http_only = case http_only {
    True -> with_secure <> "; HttpOnly"
    False -> with_secure
  }

  case same_site {
    option.Some(transaction.Strict) -> with_http_only <> "; SameSite=Strict"
    option.Some(transaction.Lax) -> with_http_only <> "; SameSite=Lax"
    option.Some(transaction.None) -> with_http_only <> "; SameSite=None"
    option.None -> with_http_only
  }
}
