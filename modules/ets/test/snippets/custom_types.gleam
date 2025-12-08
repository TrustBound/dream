//// Custom Types
////
//// Example snippet showing how to store custom types using JSON strings.

import dream_ets/config
import dream_ets/internal
import dream_ets/operations
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result

pub type User {
  User(name: String, email: String)
}

fn encode_user(user: User) -> dynamic.Dynamic {
  json.object([
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string
  |> internal.to_dynamic
}

fn decode_user() -> decode.Decoder(User) {
  decode.string
  |> decode.then(fn(json_str) {
    case json.parse(json_str, user_from_json()) {
      Ok(user) -> decode.success(user)
      Error(_) -> decode.failure(User("", ""), "User")
    }
  })
}

fn user_from_json() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(name: name, email: email))
}

pub fn store_custom_type() -> Result(String, table.EtsError) {
  use users <- result.try(
    config.new("users")
    |> config.key_string()
    |> config.value(encode_user, decode_user())
    |> config.create(),
  )

  let user = User(name: "Alice", email: "alice@example.com")
  use _ <- result.try(operations.set(users, "alice", user))

  use retrieved <- result.try(operations.get(users, "alice"))

  case retrieved {
    option.Some(u) -> Ok(u.name <> " <" <> u.email <> ">")
    option.None -> Error(table.OperationFailed("User not found"))
  }
}
