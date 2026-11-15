//// Lesson 2: the user view (src/views/user_view.gleam)

import gleam/json
import snippets/learn_building_api_user.{type User}

pub fn to_json(user: User) -> String {
  user_to_json_object(user)
  |> json.to_string()
}

pub fn list_to_json(users: List(User)) -> String {
  json.array(users, user_to_json_object)
  |> json.to_string()
}

fn user_to_json_object(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}
