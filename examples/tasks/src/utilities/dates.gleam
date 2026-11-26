//// Dates and times as text
////
//// The generated models give `client.Date` and `client.Timestamp` values.
//// The views show a date as YYYY-MM-DD and a time as Unix seconds.

import dream_postgres/client.{type Date, type Timestamp}
import gleam/float.{truncate}
import gleam/int.{parse, to_string}
import gleam/option.{type Option, None, from_result, map}
import gleam/string.{length, split}
import gleam/time/calendar.{month_from_int, month_to_int}
import gleam/time/timestamp.{to_unix_seconds}

/// A date as YYYY-MM-DD
pub fn date_to_string(date: Date) -> String {
  let calendar.Date(year: y, month: m, day: d) = date
  to_string(y)
  <> "-"
  <> pad_zero(to_string(month_to_int(m)))
  <> "-"
  <> pad_zero(to_string(d))
}

/// A timestamp as whole Unix seconds
pub fn timestamp_to_string(ts: Timestamp) -> String {
  to_unix_seconds(ts)
  |> truncate
  |> to_string
}

/// Parse a date string (YYYY-MM-DD). Returns None if parsing fails.
pub fn parse_date(date_str: String) -> Option(Date) {
  case split(date_str, "-") {
    [year_str, month_str, day_str] ->
      case parse(year_str), parse(month_str), parse(day_str) {
        Ok(year), Ok(month_int), Ok(day) ->
          month_from_int(month_int)
          |> from_result
          |> map(fn(month) { calendar.Date(year: year, month: month, day: day) })
        _, _, _ -> None
      }
    _ -> None
  }
}

fn pad_zero(s: String) -> String {
  case length(s) {
    1 -> "0" <> s
    _ -> s
  }
}
