//// Response conversion from Dream to Mist format
////
//// The reference [Dream vs Mist](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/dream-vs-mist.md) shows what this conversion does for you.
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
import gleam/time/calendar
import gleam/time/timestamp
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
/// - Body (Text, Bytes or Stream to Mist ResponseData)
///
/// The conversion handles the three body types:
/// - `Text`: Converted to bytes and sent immediately
/// - `Bytes`: Sent as-is
/// - `Stream`: Sent with chunked transfer encoding on the connection of
///   `mist_request`
///
/// ## Parameters
///
/// - `mist_request`: The Mist request that the response answers. A `Stream`
///   body uses its connection.
/// - `dream_response`: Dream Response with all fields populated
///
/// ## Returns
///
/// Mist HTTP response ready to send to the client
///
/// ## Example
///
/// ### Convert a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_response_convert.gleam#L9-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn send_user(
///   mist_request: http_request.Request(Connection),
///   user_json: String,
/// ) -> http_response.Response(ResponseData) {
///   // Internal use - normally called by the request handler
///   let dream_response = response.json_response(200, user_json)
///   let mist_response = convert(mist_request, dream_response)
///   // Mist server sends mist_response to client
///   mist_response
/// }
/// ```
pub fn convert(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
) -> http_response.Response(ResponseData) {
  case dream_response.body {
    Text(text) ->
      fixed_response(dream_response, MistBytes(bytes_tree.from_string(text)))
    DreamBytes(bytes) ->
      fixed_response(
        dream_response,
        MistBytes(bytes_tree.from_bit_array(bytes)),
      )
    Stream(stream) -> convert_stream(mist_request, dream_response, stream)
  }
}

fn fixed_response(
  dream_response: Response,
  response_data: ResponseData,
) -> http_response.Response(ResponseData) {
  http_response.new(dream_response.status)
  |> http_response.set_body(response_data)
  |> set_all_headers(build_response_headers(dream_response))
}

/// Send a Dream stream body as a Mist chunked response
///
/// Uses mist's actor-based chunked API to drain a Dream yielder,
/// sending each element as an HTTP chunk. Requires the original mist
/// request for connection access.
///
/// The chunk actor does not start draining until `mist.chunked` has
/// returned. On HTTP/1.1 mist hands the socket to the chunk actor only
/// after the actor has started; a stream that finishes before that
/// handoff makes the actor exit first, the handoff fails, and mist
/// answers the request with a 500 after the chunked body was already sent.
/// So the actor reports its subject back here, and the first `DrainNext`
/// is sent from the request process once `mist.chunked` is done.
fn convert_stream(
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

  let drain_subject = process.new_subject()

  let mist_response =
    mist.chunked(
      request: mist_request,
      response: base_response,
      init: fn(subject) {
        process.send(drain_subject, subject)
        DrainState(remaining: stream, subject: subject)
      },
      loop: drain_yielder_loop,
    )

  start_draining(drain_subject)

  mist_response
}

/// Send the first `DrainNext` to the chunk actor
///
/// The actor's `init` runs to completion before `mist.chunked` returns,
/// so its subject is already in this process's mailbox when the actor
/// started. When mist could not start the actor it has already returned
/// an error response, and there is nothing to drain.
fn start_draining(
  drain_subject: process.Subject(process.Subject(DrainMessage)),
) -> Nil {
  case process.receive(drain_subject, chunk_actor_start_timeout_ms) {
    Ok(subject) -> process.send(subject, DrainNext)
    Error(Nil) -> Nil
  }
}

/// Matches the initialisation timeout mist gives the chunk actor
const chunk_actor_start_timeout_ms = 1000

fn convert_header_to_tuple(header: Header) -> #(String, String) {
  #(string.lowercase(header_name(header)), header_value(header))
}

fn add_cookie_header(
  headers: List(#(String, String)),
  cookie: Cookie,
) -> List(#(String, String)) {
  let cookie_header = format_cookie_header(cookie)
  [#("set-cookie", cookie_header), ..headers]
}

fn build_response_headers(dream_response: Response) -> List(#(String, String)) {
  let headers = list.map(dream_response.headers, convert_header_to_tuple)
  let headers_with_cookies =
    list.fold(dream_response.cookies, headers, add_cookie_header)
  case dream_response.content_type {
    option.Some(content_type) ->
      list.key_set(headers_with_cookies, "content-type", content_type)
    option.None -> headers_with_cookies
  }
}

fn add_header(
  mist_response: http_response.Response(body),
  header: #(String, String),
) -> http_response.Response(body) {
  case header.0 {
    "set-cookie" ->
      http_response.prepend_header(mist_response, header.0, header.1)
    _ -> http_response.set_header(mist_response, header.0, header.1)
  }
}

fn set_all_headers(
  mist_response: http_response.Response(body),
  headers: List(#(String, String)),
) -> http_response.Response(body) {
  list.fold(headers, mist_response, add_header)
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
    option.Some(expiry) -> base <> "; Expires=" <> format_http_date(expiry)
    option.None -> base
  }

  let with_max_age = case max_age {
    option.Some(age) -> with_expires <> "; Max-Age=" <> int.to_string(age)
    option.None -> with_expires
  }

  let with_domain = case domain {
    option.Some(domain_name) -> with_max_age <> "; Domain=" <> domain_name
    option.None -> with_max_age
  }

  let with_path = case path {
    option.Some(cookie_path) -> with_domain <> "; Path=" <> cookie_path
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

/// Writes a time as an HTTP date in the IMF-fixdate form of RFC 9110
/// section 5.6.7, which RFC 6265 section 4.1.1 requires for `Expires`, for
/// example `Tue, 14 Nov 2023 22:13:20 GMT`. The time is in seconds since the
/// Unix epoch and is written in UTC.
fn format_http_date(seconds_since_epoch: Int) -> String {
  let #(date, time) =
    timestamp.from_unix_seconds(seconds_since_epoch)
    |> timestamp.to_calendar(calendar.utc_offset)
  day_name(seconds_since_epoch)
  <> ", "
  <> pad_number(date.day, 2)
  <> " "
  <> month_name(date.month)
  <> " "
  <> pad_number(date.year, 4)
  <> " "
  <> pad_number(time.hours, 2)
  <> ":"
  <> pad_number(time.minutes, 2)
  <> ":"
  <> pad_number(time.seconds, 2)
  <> " GMT"
}

const seconds_per_day = 86_400

/// The day names in order from Thursday, the day of 1 January 1970.
const day_names_from_thursday = "ThuFriSatSunMonTueWed"

/// The day of the week, from the whole days since the epoch. The remainders
/// are made non-negative, so a time before the epoch gets the correct day.
fn day_name(seconds_since_epoch: Int) -> String {
  let seconds_into_day =
    { seconds_since_epoch % seconds_per_day + seconds_per_day }
    % seconds_per_day
  let days_since_epoch =
    { seconds_since_epoch - seconds_into_day } / seconds_per_day
  let day_of_week = { days_since_epoch % 7 + 7 } % 7
  string.slice(day_names_from_thursday, day_of_week * 3, 3)
}

/// The month names in order from January.
const month_names_from_january = "JanFebMarAprMayJunJulAugSepOctNovDec"

fn month_name(month: calendar.Month) -> String {
  let month_index = calendar.month_to_int(month) - 1
  string.slice(month_names_from_january, month_index * 3, 3)
}

/// Writes `number` in decimal with zeros in front, to at least `width`
/// digits.
fn pad_number(number: Int, width: Int) -> String {
  string.pad_start(int.to_string(number), to: width, with: "0")
}
