//// User model - data operations only
////
//// This module handles database operations and input validation.
//// Presentation logic (JSON encoding) lives in views/user_view.

import sql
import gleam/dynamic/decode
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
