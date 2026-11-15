//// Example for the doc of `error.UnprocessableContent`.

import dream/http/error.{type Error, UnprocessableContent}
import gleam/list

pub fn check_email(
  email: String,
  registered: List(String),
) -> Result(String, Error) {
  case list.contains(registered, email) {
    True -> Error(UnprocessableContent("Email already registered"))
    False -> Ok(email)
  }
}

pub fn check_dates(start_date: Int, end_date: Int) -> Result(Nil, Error) {
  case start_date < end_date {
    True -> Ok(Nil)
    False -> Error(UnprocessableContent("Start date must be before end date"))
  }
}
