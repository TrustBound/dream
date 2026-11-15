//// Naming conventions: Variable and Parameter Naming
////
//// The types and helpers that the three `show_user` controllers share:
//// `naming_variables_good` uses full, short names, `naming_variables_abbreviated`
//// uses abbreviations, and `naming_variables_verbose` uses names that are
//// too long.

import dream/http.{type Response}
import dream/http/error.{type Error, NotFound, message, to_status_code}
import gleam/list
import gleam/result

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(users: List(User))
}

pub fn find_user(users: List(User), id: Int) -> Result(User, Error) {
  list.find(users, fn(user) { user.id == id })
  |> result.replace_error(NotFound("User not found"))
}

pub fn respond_with_user(user_result: Result(User, Error)) -> Response {
  case user_result {
    Ok(user) -> http.text_response(http.ok, user.name)
    Error(error) -> http.text_response(to_status_code(error), message(error))
  }
}
