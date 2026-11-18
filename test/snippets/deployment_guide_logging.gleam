import gleam/io
import gleam/json.{type Json}
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}

pub fn log_info(message: String, metadata: Json) -> Nil {
  format_info_line(message, metadata, timestamp.system_time())
  |> io.println
}

pub fn format_info_line(
  message: String,
  metadata: Json,
  time: Timestamp,
) -> String {
  json.object([
    #("level", json.string("info")),
    #("message", json.string(message)),
    #("metadata", metadata),
    // ISO 8601 in UTC, for example 2026-01-31T09:30:00Z
    #("timestamp", json.string(timestamp.to_rfc3339(time, calendar.utc_offset))),
  ])
  |> json.to_string
}
