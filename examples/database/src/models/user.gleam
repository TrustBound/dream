//// User model - data operations only
////
//// This module handles database operations and returns domain types.
//// Presentation logic (JSON encoding) lives in views/user_view.

import dream/http/error.{type Error, InternalServerError, NotFound}
import dream_postgres_client
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/time/timestamp
import sql
import types/user.{type User, User}

/// List all users
pub fn list(db: dream_postgres_client.Connection) -> Result(List(User), Error) {
  case sql.list_users(db) {
    Ok(returned) -> Ok(extract_all_users(returned))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Get a single user by ID
pub fn get(
  db: dream_postgres_client.Connection,
  id: Int,
) -> Result(User, Error) {
  case sql.get_user(db, id) {
    Ok(returned) -> extract_first_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Create a new user
pub fn create(
  db: dream_postgres_client.Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.create_user(db, name, email) {
    Ok(returned) -> extract_created_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Update a user
pub fn update(
  db: dream_postgres_client.Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.update_user(db, name, email, id) {
    Ok(returned) -> extract_updated_user(returned)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Delete a user
pub fn delete(
  db: dream_postgres_client.Connection,
  id: Int,
) -> Result(Nil, Error) {
  case sql.delete_user(db, id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database error"))
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
  returned: dream_postgres_client.Returned(sql.GetUserRow),
) -> Result(User, Error) {
  case returned.rows {
    [row] -> Ok(row_to_user(row))
    [] -> Error(NotFound("User not found"))
    _ -> Error(NotFound("User not found"))
  }
}

fn extract_all_users(
  returned: dream_postgres_client.Returned(sql.ListUsersRow),
) -> List(User) {
  list.map(returned.rows, row_to_user_list)
}

fn extract_created_user(
  returned: dream_postgres_client.Returned(sql.CreateUserRow),
) -> Result(User, Error) {
  case returned.rows {
    [row] -> Ok(row_to_user_create(row))
    [] -> Error(InternalServerError("Failed to create user"))
    _ -> Error(InternalServerError("Failed to create user"))
  }
}

fn extract_updated_user(
  returned: dream_postgres_client.Returned(sql.UpdateUserRow),
) -> Result(User, Error) {
  case returned.rows {
    [row] -> Ok(row_to_user_update(row))
    [] -> Error(NotFound("User not found"))
    _ -> Error(NotFound("User not found"))
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
