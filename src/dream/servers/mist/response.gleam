//// Response conversion from Dream to Mist format
////
//// This module provides functions to convert Dream HTTP responses
//// to Mist response format, including status code, header, and cookie conversion.
////
//// This is an internal module used by the Dream server implementation.
//// Most applications won't need to use this directly.

import dream/http/cookie.{type Cookie, Cookie, Lax, None, Strict}
import dream/http/header.{type Header, header_name, header_value}
import dream/http/response.{type Response, Bytes as DreamBytes, Stream, Text}
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/yielder
import mist.{type Connection, type ResponseData, Bytes as MistBytes}

/// Convert Dream response to Mist response format
///
/// Converts a Dream HTTP response to Mist's response format.
/// This includes converting:
///
/// - Status code (Int remains Int)
/// - Headers (Dream Header to Mist tuple format)
/// - Cookies (each cookie becomes its own `Set-Cookie` header per RFC 6265)
/// - Body (Text/Bytes/Stream to Mist ResponseData)
///
/// The conversion handles all three body types:
/// - `Text`: Converted to bytes and sent immediately
/// - `Bytes`: Sent as-is
/// - `Stream`: Converted to chunked transfer encoding
///
/// ## Parameters
///
/// - `dream_resp`: Dream Response with all fields populated
///
/// ## Returns
///
/// Mist HTTP response ready to send to the client
///
/// ## Example
///
/// ```gleam
/// // Internal use - normally called by the request handler
/// let dream_resp = response.json_response(200, user_json)
/// let mist_resp = convert(dream_resp)
/// // Mist server sends mist_resp to client
/// ```
pub fn convert(dream_resp: Response) -> http_response.Response(ResponseData) {
  let headers = build_response_headers(dream_resp)

  let response_data = case dream_resp.body {
    Text(text) -> MistBytes(bytes_tree.from_string(text))
    DreamBytes(bytes) -> MistBytes(bytes_tree.from_bit_array(bytes))
    Stream(_stream) ->
      panic as "Stream bodies must use convert_stream with mist request"
  }

  http_response.new(dream_resp.status)
  |> http_response.set_body(response_data)
  |> set_all_headers(headers)
}

/// Convert a Dream streaming response to Mist chunked response
///
/// Uses mist's actor-based chunked API to drain a Dream yielder,
/// sending each element as an HTTP chunk. Requires the original mist
/// request for connection access.
///
/// ## Example
///
/// ```gleam
/// // Internal use - called by the handler when body is Stream
/// let mist_resp = convert_stream(mist_request, dream_resp, stream)
/// ```
pub fn convert_stream(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
  stream: yielder.Yielder(BitArray),
) -> http_response.Response(ResponseData) {
  let headers = build_response_headers(dream_response)

  let base_response =
    http_response.Response(
      status: dream_response.status,
      headers: [],
      body: Nil,
    )
    |> set_all_headers(headers)

  mist.chunked(
    request: mist_request,
    response: base_response,
    init: fn(subject) {
      process.send(subject, DrainNext)
      DrainState(remaining: stream, subject: subject)
    },
    loop: drain_yielder_loop,
  )
}

fn convert_header_to_tuple(header: Header) -> #(String, String) {
  #(string.lowercase(header_name(header)), header_value(header))
}

fn add_cookie_header(
  acc: List(#(String, String)),
  cookie: Cookie,
) -> List(#(String, String)) {
  let cookie_header = format_cookie_header(cookie)
  [#("set-cookie", cookie_header), ..acc]
}

fn build_response_headers(dream_resp: Response) -> List(#(String, String)) {
  let headers = list.map(dream_resp.headers, convert_header_to_tuple)
  let headers_with_cookies =
    list.fold(dream_resp.cookies, headers, add_cookie_header)
  case dream_resp.content_type {
    option.Some(ct) -> list.key_set(headers_with_cookies, "content-type", ct)
    option.None -> headers_with_cookies
  }
}

fn add_header(
  acc: http_response.Response(body),
  header: #(String, String),
) -> http_response.Response(body) {
  case header.0 {
    "set-cookie" -> http_response.prepend_header(acc, header.0, header.1)
    _ -> http_response.set_header(acc, header.0, header.1)
  }
}

fn set_all_headers(
  resp: http_response.Response(body),
  headers: List(#(String, String)),
) -> http_response.Response(body) {
  list.fold(headers, resp, add_header)
}

type DrainMessage {
  DrainNext
}

type DrainState {
  DrainState(
    remaining: yielder.Yielder(BitArray),
    subject: process.Subject(DrainMessage),
  )
}

fn drain_yielder_loop(
  state: DrainState,
  _message: DrainMessage,
  connection: Connection,
) -> mist.ChunkNext(DrainState) {
  case yielder.step(state.remaining) {
    yielder.Next(chunk, rest) ->
      send_chunk_and_continue(state, chunk, rest, connection)
    yielder.Done -> mist.ChunkStop
  }
}

fn send_chunk_and_continue(
  state: DrainState,
  chunk: BitArray,
  rest: yielder.Yielder(BitArray),
  connection: Connection,
) -> mist.ChunkNext(DrainState) {
  case mist.send_chunk(connection, chunk) {
    Ok(Nil) -> {
      process.send(state.subject, DrainNext)
      mist.ChunkContinue(DrainState(remaining: rest, subject: state.subject))
    }
    Error(Nil) -> mist.ChunkStop
  }
}

/// Format a cookie for the Set-Cookie header
fn format_cookie_header(cookie: Cookie) -> String {
  let Cookie(
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
    option.Some(Strict) -> with_http_only <> "; SameSite=Strict"
    option.Some(Lax) -> with_http_only <> "; SameSite=Lax"
    option.Some(None) -> with_http_only <> "; SameSite=None"
    option.None -> with_http_only
  }
}
