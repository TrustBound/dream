//// The JSON text of a time: RFC 3339 in UTC with exactly six digits after
//// the second, for example "2026-01-02T03:04:05.120000Z". The RFC 3339 text
//// of gleam_time drops the zeros at the end of the fraction, so the length
//// of a response would change with the time of the request.

import gleam/int
import gleam/json
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}

/// The time as a JSON string with six digits after the second.
pub fn to_json(time: Timestamp) -> json.Json {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(time)
  let whole =
    timestamp.from_unix_seconds(seconds)
    |> timestamp.to_rfc3339(calendar.utc_offset)
  let microseconds =
    int.to_string(nanoseconds / 1000) |> string.pad_start(to: 6, with: "0")
  json.string(string.drop_end(whole, 1) <> "." <> microseconds <> "Z")
}
