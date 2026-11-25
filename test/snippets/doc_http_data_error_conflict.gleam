//// Example for the doc of `error.Conflict`.

import dream/http/error.{type Error, Conflict}
import gleam/list

pub fn check_email(
  email: String,
  registered: List(String),
) -> Result(String, Error) {
  case list.contains(registered, email) {
    True -> Error(Conflict("Email already registered"))
    False -> Ok(email)
  }
}

pub fn check_version(sent: Int, current: Int) -> Result(Nil, Error) {
  case sent == current {
    True -> Ok(Nil)
    False -> Error(Conflict("The post changed after you loaded it"))
  }
}
