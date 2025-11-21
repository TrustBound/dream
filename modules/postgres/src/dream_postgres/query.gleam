//// Database query helpers
////
//// Simple utilities for extracting rows from Pog query results. Use these after
//// executing database queries to get your data out cleanly.
////
//// ## Example
////
//// ```gleam
//// import dream_postgres/query
////
//// case sql.get_user(db, id) |> query.first_row() {
////   Ok(user) -> Ok(decode_user(user))
////   Error(query.NotFound) -> Error("User not found")
////   Error(query.DatabaseError) -> Error("Database error")
//// }
//// ```

import gleam/list
import pog

/// Query error types
///
/// Simplified error types for query results. Converts Pog's `QueryError`
/// into a simpler two-variant type for easier error handling.
///
/// ## Variants
///
/// - `NotFound`: Query succeeded but returned no rows
/// - `DatabaseError`: Query failed (connection error, SQL error, etc.)
pub type QueryError {
  NotFound
  DatabaseError
}

/// Extract the first row from a query result
///
/// Extracts the first row from a Pog query result. This is useful for
/// queries that should return exactly one row (e.g., "get by ID" queries).
///
/// Returns `NotFound` if the query succeeded but returned no rows, or
/// `DatabaseError` if the query itself failed.
///
/// ## Parameters
///
/// - `result`: The result from a Pog query execution
///
/// ## Returns
///
/// - `Ok(row)`: First row found
/// - `Error(NotFound)`: Query succeeded but no rows returned
/// - `Error(DatabaseError)`: Query failed (connection error, SQL error, etc.)
///
/// ## Example
///
/// ```gleam
/// import dream_postgres/query
/// import user/sql
///
/// case sql.get_user(db, id) |> query.first_row() {
///   Ok(user) -> user_view.respond(user)
///   Error(query.NotFound) -> not_found_response()
///   Error(query.DatabaseError) -> error_response()
/// }
/// ```
pub fn first_row(
  result: Result(pog.Returned(row), pog.QueryError),
) -> Result(row, QueryError) {
  case result {
    Ok(db_result) ->
      case list.first(db_result.rows) {
        Ok(row) -> Ok(row)
        Error(_) -> Error(NotFound)
      }
    Error(_) -> Error(DatabaseError)
  }
}

/// Extract all rows from a query result
///
/// Extracts all rows from a Pog query result. This is useful for queries
/// that return multiple rows (e.g., "list all" queries).
///
/// Returns an empty list if the query succeeded but found no rows, or
/// `DatabaseError` if the query itself failed.
///
/// ## Parameters
///
/// - `result`: The result from a Pog query execution
///
/// ## Returns
///
/// - `Ok(List(row))`: All rows (may be empty)
/// - `Error(DatabaseError)`: Query failed (connection error, SQL error, etc.)
///
/// ## Example
///
/// ```gleam
/// import dream_postgres/query
/// import user/sql
///
/// case sql.list_users(db) |> query.all_rows() {
///   Ok(users) -> user_view.respond_list(users)
///   Error(query.DatabaseError) -> error_response()
/// }
/// ```
pub fn all_rows(
  result: Result(pog.Returned(row), pog.QueryError),
) -> Result(List(row), QueryError) {
  case result {
    Ok(db_result) -> Ok(db_result.rows)
    Error(_) -> Error(DatabaseError)
  }
}
