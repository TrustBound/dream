//// User model - data operations and transformations
////
//// This module encapsulates all user-related data operations including
//// database queries, request validation, and response encoding.

import dream/utilities/json/encoders
import examples/database/sql
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp
import pog

/// List all users
pub fn list(
  db: pog.Connection,
) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

/// Get a single user by ID
pub fn get(
  db: pog.Connection,
  id: Int,
) -> Result(pog.Returned(sql.GetUserRow), pog.QueryError) {
  sql.get_user(db, id)
}

/// Create a new user
pub fn create(
  db: pog.Connection,
  name: String,
  email: String,
) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError) {
  sql.create_user(db, name, email)
}

/// Update a user
pub fn update(
  db: pog.Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(pog.Returned(sql.UpdateUserRow), pog.QueryError) {
  sql.update_user(db, name, email, id)
}

/// Delete a user
pub fn delete(
  db: pog.Connection,
  id: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  sql.delete_user(db, id)
}

/// Decoder for user create/update requests
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

/// JSON encoder for GetUserRow
pub fn encode(user: sql.GetUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

/// JSON encoder for ListUsersRow
pub fn encode_list(user: sql.ListUsersRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

/// JSON encoder for CreateUserRow
pub fn encode_create(user: sql.CreateUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

/// JSON encoder for UpdateUserRow
pub fn encode_update(user: sql.UpdateUserRow) -> json.Json {
  encode_user_fields(user.id, user.name, user.email, user.created_at)
}

fn encode_user_fields(
  id: Int,
  name: String,
  email: String,
  created_at: option.Option(timestamp.Timestamp),
) -> json.Json {
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("email", json.string(email)),
    #("created_at", encoders.timestamp(created_at)),
  ])
}
