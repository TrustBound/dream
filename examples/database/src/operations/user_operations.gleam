//// User operations - Business logic for user management
////
//// This module contains pure domain logic for user operations.
//// It returns Result types with dream.Error.

import dream/http/error.{type Error}
import models/user as user_model
import pog.{type Connection}
import types/user.{type User}

/// Get a user by ID
pub fn get_user(db: Connection, id: Int) -> Result(User, Error) {
  user_model.get(db, id)
}

/// List all users
pub fn list_users(db: Connection) -> Result(List(User), Error) {
  user_model.list(db)
}

/// Create a new user
pub fn create_user(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  user_model.create(db, name, email)
}

/// Update a user
pub fn update_user(
  db: Connection,
  id: Int,
  name: String,
  email: String,
) -> Result(User, Error) {
  user_model.update(db, id, name, email)
}

/// Delete a user
pub fn delete_user(db: Connection, id: Int) -> Result(Nil, Error) {
  user_model.delete(db, id)
}
