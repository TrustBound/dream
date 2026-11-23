//// The user model that the testing guide's examples test.

import dream/http/validation.{type ValidationError}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

pub type User {
  User(id: Int, name: String, email: String)
}

pub fn create_user(name: String, email: String) -> Result(User, String) {
  validate_email(email)
  |> result.map(fn(valid_email) { User(id: 1, name: name, email: valid_email) })
}

pub fn validate_email(email: String) -> Result(String, String) {
  case string.contains(email, "@") {
    True -> Ok(email)
    False -> Error("Email must contain @")
  }
}

pub fn list_users() -> List(User) {
  [
    User(id: 1, name: "Alice", email: "alice@example.com"),
    User(id: 2, name: "Bob", email: "bob@example.com"),
  ]
}

pub fn find_user(id: Int) -> Option(User) {
  list_users()
  |> list.find(fn(user) { user.id == id })
  |> option.from_result()
}

pub fn validate_user(json_body: String) -> Result(User, List(ValidationError)) {
  validation.validate_json(json_body, user_decoder())
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(id: id, name: name, email: email))
}
