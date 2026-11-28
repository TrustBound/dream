//// Naming conventions: Serialization
////
//// `serialize_{noun}` encodes a value to store or send it.
//// `deserialize_{noun}` decodes it again.

import gleam/bit_array
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/result
import gleam/string

pub type User {
  User(id: Int, name: String)
}

pub type Session {
  Session(id: String, user_id: Int)
}

pub fn serialize_user(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string
}

pub fn serialize_session(session: Session) -> BitArray {
  bit_array.from_string(session.id <> ":" <> int.to_string(session.user_id))
}

pub fn deserialize_user(text: String) -> Result(User, json.DecodeError) {
  json.parse(text, user_decoder())
}

pub fn deserialize_session(bytes: BitArray) -> Result(Session, Nil) {
  use text <- result.try(bit_array.to_string(bytes))
  use #(id, user_id_text) <- result.try(string.split_once(text, ":"))
  use user_id <- result.try(int.parse(user_id_text))
  Ok(Session(id:, user_id:))
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(User(id:, name:))
}
