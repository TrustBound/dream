//// The JSON text of a time: RFC 3339 in UTC with exactly six digits after
//// the second, for example "2026-01-02T03:04:05.120000Z". The RFC 3339 text
//// of gleam_time drops the zeros at the end of the fraction, so the length
//// of a response would change with the time of the request.

import gleam/int.{to_string}
import gleam/json.{type Json}
import gleam/string.{drop_end, pad_start}
import gleam/time/calendar.{utc_offset}
import gleam/time/timestamp.{
  type Timestamp, from_unix_seconds, to_rfc3339, to_unix_seconds_and_nanoseconds,
}

/// The time as a JSON string with six digits after the second.
pub fn to_json(time: Timestamp) -> Json {
  let #(seconds, nanoseconds) = to_unix_seconds_and_nanoseconds(time)
  let whole =
    from_unix_seconds(seconds)
    |> to_rfc3339(utc_offset)
  let microseconds =
    to_string(nanoseconds / 1000) |> pad_start(to: 6, with: "0")
  json.string(drop_end(whole, 1) <> "." <> microseconds <> "Z")
}
