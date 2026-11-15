//// Example for the module doc of `dream/http/error`.

import dream/http/error.{type Error, BadRequest, NotFound}
import gleam/list
import gleam/result

pub type User {
  User(id: Int, name: String)
}

pub fn get_user(users: List(User), id: Int) -> Result(User, Error) {
  list.find(users, fn(user) { user.id == id })
  |> result.replace_error(NotFound("User not found"))
}

pub fn create_user(users: List(User), name: String) -> Result(User, Error) {
  case name {
    "" -> Error(BadRequest("Name must not be empty"))
    _ -> Ok(User(id: list.length(users) + 1, name: name))
  }
}
