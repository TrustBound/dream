//// Example for the doc of `error.BadRequest`.

import dream/http/error.{type Error, BadRequest}

pub fn check_signup(email: String, id: Int) -> Result(Nil, Error) {
  case email, id {
    "", _ -> Error(BadRequest("Field 'email' is required"))
    _, id if id < 1 -> Error(BadRequest("ID must be a positive integer"))
    _, _ -> Ok(Nil)
  }
}
