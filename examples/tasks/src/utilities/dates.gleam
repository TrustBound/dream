//// Dates and times as text
////
//// The generated models give `client.Date` and `client.Timestamp` values.
//// The views show a date as YYYY-MM-DD and a time as Unix seconds.

import dream_postgres/client
import gleam/float
import gleam/int
import gleam/option.{type Option}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp

/// A date as YYYY-MM-DD
pub fn date_to_string(date: client.Date) -> String {
  let calendar.Date(year: y, month: m, day: d) = date
  int.to_string(y)
  <> "-"
  <> pad_zero(int.to_string(calendar.month_to_int(m)))
  <> "-"
  <> pad_zero(int.to_string(d))
}

/// A timestamp as whole Unix seconds
pub fn timestamp_to_string(ts: client.Timestamp) -> String {
  timestamp.to_unix_seconds(ts)
  |> float.truncate
  |> int.to_string
}

/// Parse a date string (YYYY-MM-DD). Returns None if parsing fails.
pub fn parse_date(date_str: String) -> Option(client.Date) {
  case string.split(date_str, "-") {
    [year_str, month_str, day_str] ->
      case int.parse(year_str), int.parse(month_str), int.parse(day_str) {
        Ok(year), Ok(month_int), Ok(day) ->
          calendar.month_from_int(month_int)
          |> option.from_result
          |> option.map(fn(month) {
            calendar.Date(year: year, month: month, day: day)
          })
        _, _, _ -> option.None
      }
    _ -> option.None
  }
}

fn pad_zero(s: String) -> String {
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}
