//// README: JSON APIs
////
//// A controller that reads a user from Services and returns JSON, as shown
//// in the root README.

import dream/http.{json_response, not_found, ok}
import gleam/json
import gleam/list

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(db: List(User))
}

pub fn get_user(_request, _context, services: Services) {
  case find_user(services.db, id: 1) {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(Nil) -> json_response(not_found, "{}")
  }
}

fn find_user(db: List(User), id id: Int) -> Result(User, Nil) {
  list.find(db, fn(user) { user.id == id })
}

fn user_to_json(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string
}
