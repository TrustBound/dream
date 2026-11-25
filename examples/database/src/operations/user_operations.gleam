//// User operations - Business logic for user management
////
//// This module contains pure domain logic for user operations.
//// It calls the functions that dream_model generated in models/user,
//// which return Result types with dream.Error.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import models/user.{type User}

/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  user.get(db, id)
}

/// List all users
pub fn list_users(db: Connection) -> Result(List(User), Error) {
  user.list(db)
}

/// Create a new user
pub fn create_user(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  user.create(db, name, email)
}

/// Update a user
pub fn update_user(
  db: Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  user.update(db, name, email, id)
}

/// Delete a user
pub fn delete_user(db: Connection, id: Int) -> Result(Nil, Error) {
  user.delete(db, id)
}
