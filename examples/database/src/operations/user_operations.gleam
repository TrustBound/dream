//// User operations - Business logic for user management
////
//// This module contains pure domain logic for user operations.
//// It calls the functions that dream_model generated in models/user,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error, Conflict, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{
  type Connection, type QueryError, violated_constraint,
}
import gleam/result.{map_error}
import models/user.{type User, create, delete, get, list, update}

/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  get(db, id)
  |> map_error(user_error)
}

/// List all users
pub fn list_users(db: Connection) -> Result(List(User), Error) {
  list(db)
  |> map_error(user_error)
}

/// Create a new user
pub fn create_user(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  create(db, name, email)
  |> map_error(user_error)
}

/// Update a user
pub fn update_user(
  db: Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  update(db, name, email, id)
  |> map_error(user_error)
}

/// Delete a user
pub fn delete_user(db: Connection, id: Int) -> Result(Nil, Error) {
  delete(db, id)
  |> map_error(user_error)
}

/// The Dream error of a model error. A missing row and a taken email keep
/// their own texts. Every other error goes through `error.from_shared`,
/// which never shows the developer message of the model error.
fn user_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("User not found")
    dream_errors.Conflict(cause:, ..) ->
      case violated_constraint(cause) {
        Ok("users_email_key") -> Conflict("Email already taken")
        _ -> from_shared(model_error)
      }
    _ -> from_shared(model_error)
  }
}
