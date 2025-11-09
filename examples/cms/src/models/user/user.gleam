//// User model - data access functions (repository pattern)
////
//// Returns domain types, not database-specific types.
//// Demonstrates clean pattern: no nested cases, no anonymous functions.

import dream_postgres/client as postgres
import gleam/list
import gleam/result
import models/user/sql
import types/errors.{type DataError, DatabaseError, NotFound}
import types/user.{type User, User}

/// Get a single user by ID
pub fn get(db: postgres.Connection, id: Int) -> Result(User, DataError) {
  sql.get_user(db, id)
  |> result.map_error(to_data_error)
  |> result.try(extract_single_user)
}

/// List all users
pub fn list(db: postgres.Connection) -> Result(List(User), DataError) {
  sql.list_users(db)
  |> result.map_error(to_data_error)
  |> result.map(extract_all_users)
}

/// Create a new user
pub fn create(
  db: postgres.Connection,
  username: String,
  email: String,
) -> Result(User, DataError) {
  sql.create_user(db, username, email)
  |> result.map_error(to_data_error)
  |> result.try(extract_created_user)
}

fn extract_created_user(
  returned: postgres.Returned(sql.CreateUserRow),
) -> Result(User, DataError) {
  case returned.rows {
    [row] -> Ok(from_create_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn from_create_row(row: sql.CreateUserRow) -> User {
  User(
    id: row.id,
    username: row.username,
    email: row.email,
    created_at: row.created_at,
  )
}

// Private helpers - all named functions

fn extract_single_user(
  returned: postgres.Returned(sql.GetUserRow),
) -> Result(User, DataError) {
  case returned.rows {
    [row] -> Ok(from_row(row))
    [] -> Error(NotFound)
    _ -> Error(NotFound)
  }
}

fn extract_all_users(returned: postgres.Returned(sql.ListUsersRow)) -> List(User) {
  list.map(returned.rows, from_row_list)
}

fn from_row(row: sql.GetUserRow) -> User {
  User(
    id: row.id,
    username: row.username,
    email: row.email,
    created_at: row.created_at,
  )
}

fn from_row_list(row: sql.ListUsersRow) -> User {
  User(
    id: row.id,
    username: row.username,
    email: row.email,
    created_at: row.created_at,
  )
}

fn to_data_error(_: postgres.QueryError) -> DataError {
  DatabaseError
}

