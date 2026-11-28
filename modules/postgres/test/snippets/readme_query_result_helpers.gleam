//// README: Query Result Helpers
////
//// Turns Pog results into values, with one message for each error.

import dream_postgres/client as postgres
import dream_postgres/query
import gleam/list
import gleam/string

pub type User {
  User(id: Int, name: String)
}

// First row (for "get by ID" queries)
pub fn user_from_result(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> Result(User, String) {
  case query.first_row(result) {
    Ok(user) -> {
      // pog.returning already decoded the row to your type
      Ok(user)
    }
    Error(query.NotFound) -> {
      // Query succeeded but no rows returned
      Error("User not found")
    }
    Error(query.DatabaseError) -> {
      // Query failed (connection error, SQL error, etc.)
      Error("Database error")
    }
  }
}

// All rows (for "list" queries)
pub fn user_names_from_result(
  result: Result(postgres.Returned(User), postgres.QueryError),
) -> Result(List(String), String) {
  case query.all_rows(result) {
    Ok(users) -> {
      // Process all rows
      Ok(list.map(users, fn(user) { user.name }))
    }
    Error(error) -> {
      Error("Database error: " <> string.inspect(error))
    }
  }
}
