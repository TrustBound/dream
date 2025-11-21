//// User view - presentation logic for users
////
//// Pure formatting functions: User → String
//// No Result types, no Response types, no error handling.

import dream_json/json_encoders as encoders
import gleam/json
import gleam/list
import gleam/option
import types/user.{type User}

/// Format single user as JSON string
pub fn to_json(user: User) -> String {
  to_json_object(user)
  |> json.to_string()
}

/// Format list of users as JSON array string
pub fn list_to_json(users: List(User)) -> String {
  list.map(users, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

// Private helpers - all named functions

fn to_json_object(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
    #("created_at", encoders.timestamp(option.Some(user.created_at))),
  ])
}

fn identity(x: a) -> a {
  x
}
