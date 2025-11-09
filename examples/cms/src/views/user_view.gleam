//// User view - formatting functions (serializer pattern)
////
//// Pure transformations: User -> String
//// No Result types, no Response types, no error handling.

import dream_helpers/json_encoders
import gleam/int
import gleam/json
import gleam/list
import types/user.{type User}

/// Format single user as JSON
pub fn to_json(user: User) -> String {
  to_json_object(user)
  |> json.to_string()
}

/// Format list of users as JSON array
pub fn list_to_json(users: List(User)) -> String {
  list.map(users, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

/// Format user as CSV row
pub fn to_csv(user: User) -> String {
  int.to_string(user.id)
  <> ","
  <> user.username
  <> ","
  <> user.email
  <> ","
  <> json_encoders.timestamp_to_string(user.created_at)
}

/// Format user as HTML
pub fn to_html(user: User) -> String {
  "<div class=\"user\">
    <h2>" <> user.username <> "</h2>
    <p>" <> user.email <> "</p>
  </div>"
}

// Private helpers

fn to_json_object(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("username", json.string(user.username)),
    #("email", json.string(user.email)),
    #("created_at", json.string(json_encoders.timestamp_to_string(user.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}

