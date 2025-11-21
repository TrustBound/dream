//// HTML attribute helpers for consistent and type-safe attribute generation

import gleam/list
import gleam/string

/// Generate an HTMX attribute string with double quotes
/// Example: htmx_attribute("get", "/tasks/1") -> "hx-get=\"/tasks/1\""
pub fn htmx_attribute(attr: String, value: String) -> String {
  "hx-" <> attr <> "=\"" <> value <> "\""
}

/// Generate an HTMX vals attribute with single quotes (for JSON compatibility)
/// Example: htmx_vals("{\"id\": 1}") -> "hx-vals='{\"id\": 1}'"
pub fn htmx_vals(json: String) -> String {
  "hx-vals='" <> json <> "'"
}

/// Generate a regular HTML attribute string
/// Example: attr("class", "active") -> "class=\"active\""
pub fn attr(name: String, value: String) -> String {
  name <> "=\"" <> value <> "\""
}

/// Join a list of attribute strings, filtering out empty strings
/// Example: join_attributes(["class=\"foo\"", "", "id=\"bar\""]) -> "class=\"foo\" id=\"bar\""
pub fn join_attributes(attrs: List(String)) -> String {
  attrs
  |> list.filter(fn(a) { a != "" })
  |> string.join(" ")
}
