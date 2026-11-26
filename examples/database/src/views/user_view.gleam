//// User view - presentation logic for users
////
//// Pure formatting functions: User → String
//// No Result types, no Response types, no error handling.

import gleam/json.{type Json, array, int, object, string, to_string}
import gleam/list.{map}
import gleam/option.{type Option, unwrap}
import gleam/time/timestamp.{type Timestamp, system_time}
import models/user.{type User}
import views/time_text

/// Format single user as JSON string
pub fn to_json(user: User) -> String {
  to_json_object(user)
  |> to_string()
}

/// Format list of users as JSON array string
pub fn list_to_json(users: List(User)) -> String {
  map(users, to_json_object)
  |> array(from: _, of: identity)
  |> to_string()
}

// Private helpers - all named functions

fn to_json_object(user: User) -> Json {
  object([
    #("id", int(user.id)),
    #("name", string(user.name)),
    #("email", string(user.email)),
    #("created_at", time_text.to_json(created_at(user.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}

// The created_at column has a default but can be NULL. A NULL time shows
// the current time.
fn created_at(value: Option(Timestamp)) -> Timestamp {
  unwrap(value, system_time())
}
