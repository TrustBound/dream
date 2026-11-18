//// Concepts: a view that formats a user as JSON, CSV or HTML

import dream/http.{
  type PathParam, type Response, html_response, json_response, text_response,
}
import dream/http/status
import gleam/int
import gleam/json
import gleam/option.{Some}
import gleam/string

pub type User {
  User(id: Int, email: String, name: String)
}

pub fn respond(user: User, param: PathParam) -> Response {
  case param.format {
    Some("json") -> json_response(status.ok, to_json(user))
    Some("csv") -> text_response(status.ok, to_csv(user))
    _ -> html_response(status.ok, to_html(user))
  }
}

pub fn to_json(user: User) -> String {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("name", json.string(user.name)),
  ])
  |> json.to_string()
}

pub fn to_csv(user: User) -> String {
  "id,email,name\n"
  <> int.to_string(user.id)
  <> ","
  <> quote_csv_field(user.email)
  <> ","
  <> quote_csv_field(user.name)
  <> "\n"
}

pub fn to_html(user: User) -> String {
  "<p>" <> escape_html(user.name) <> " (" <> escape_html(user.email) <> ")</p>"
}

fn quote_csv_field(field: String) -> String {
  "\"" <> string.replace(field, "\"", "\"\"") <> "\""
}

fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}
