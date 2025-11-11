//// User model - data operations only
////
//// This module handles database operations and returns domain types.
//// Presentation logic (JSON encoding) lives in views/user_view.

import types/user.{type User, User}
import types/errors.{type DataError, NotFound, DatabaseError}
import sql
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/time/timestamp
import pog

/// List all users
pub fn list(db: pog.Connection) -> Result(List(User), DataError) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(extract_all_users(returned))
    Error(_) -> Error(DatabaseError)
  }
}

/// Get a single user by ID
pub fn get(db: pog.Connection, id: Int) -> Result(User, DataError) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(DatabaseError)
  }
}

/// Create a new user
pub fn create(
  db: pog.Connection,
  name: String,
  email: String,
) -> Result(User, DataError) {
  case sql.create_user(db, name, email) {
    Ok(returned) -> extract_created_user(returned)
    Error(_) -> Error(DatabaseError)
  }
}

/// Update a user
pub fn update(
  db: pog.Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, DataError) {
  case sql.update_user(db, name, email, id) {
    Ok(returned) -> extract_updated_user(returned)
    Error(_) -> Error(DatabaseError)
  }
}

/// Delete a user
pub fn delete(db: pog.Connection, id: Int) -> Result(Nil, DataError) {
  case sql.delete_user(db, id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(DatabaseError)
  }
}

/// Decoder for user create/update requests
pub fn decoder() -> decode.Decoder(#(String, String)) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(#(name, email))
}

// Private helpers - all named functions

fn extract_first_user(
  returned: pog.Returned(sql.GetUserRow),
) -> Result(User, DataError) {
  case returned.rows {
    [row] -> Ok(row_to_user(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_all_users(returned: pog.Returned(sql.ListUsersRow)) -> List(User) {
  list.map(returned.rows, row_to_user_list)
}

fn extract_created_user(
  returned: pog.Returned(sql.CreateUserRow),
) -> Result(User, DataError) {
  case returned.rows {
    [row] -> Ok(row_to_user_create(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_updated_user(
  returned: pog.Returned(sql.UpdateUserRow),
) -> Result(User, DataError) {
  case returned.rows {
    [row] -> Ok(row_to_user_update(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn row_to_user(row: sql.GetUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_user_list(row: sql.ListUsersRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_user_create(row: sql.CreateUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}

fn row_to_user_update(row: sql.UpdateUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
    created_at: option.unwrap(row.created_at, timestamp.system_time()),
  )
}
