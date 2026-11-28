//// Example for the doc of `error.Unauthorized`.

import dream/http/error.{type Error, Unauthorized}
import gleam/list

pub fn authenticate(
  token: String,
  valid_tokens: List(String),
) -> Result(String, Error) {
  case token, list.contains(valid_tokens, token) {
    "", _ -> Error(Unauthorized("Authentication token required"))
    _, False -> Error(Unauthorized("Invalid or expired token"))
    _, True -> Ok(token)
  }
}
