//// User operations - Business logic for user management
////
//// This module contains pure domain logic for user operations.
//// It calls the functions that dream_model generated in models/user,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_errors
import dream_postgres/client.{type Connection}
import gleam/result
import models/user.{type User}

/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  user.get(db, id)
  |> result.map_error(user_error)
}

/// List all users
pub fn list_users(db: Connection) -> Result(List(User), Error) {
  user.list(db)
  |> result.map_error(user_error)
}

/// Create a new user
pub fn create_user(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  user.create(db, name, email)
  |> result.map_error(user_error)
}

/// Update a user
pub fn update_user(
  db: Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  user.update(db, name, email, id)
  |> result.map_error(user_error)
}

/// Delete a user
pub fn delete_user(db: Connection, id: Int) -> Result(Nil, Error) {
  user.delete(db, id)
  |> result.map_error(user_error)
}

/// The Dream error of a model error. A missing row and a taken email keep
/// their own texts. Every other error goes through `error.from_shared`,
/// which never shows the developer message of the model error.
fn user_error(model_error: dream_errors.Error(client.QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> error.NotFound("User not found")
    dream_errors.Conflict(cause:, ..) ->
      case client.violated_constraint(cause) {
        Ok("users_email_key") -> error.Conflict("Email already taken")
        _ -> error.from_shared(model_error)
      }
    _ -> error.from_shared(model_error)
  }
}
