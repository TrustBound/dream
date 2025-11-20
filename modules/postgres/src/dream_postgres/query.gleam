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
pub type QueryError {
  NotFound
  DatabaseError
}

/// Extract the first row from a query result
///
/// Returns `NotFound` if the query succeeded but returned no rows,
/// or `DatabaseError` if the query failed.
///
/// ## Example
///
/// ```gleam
/// case user.get(db, id) |> query.first_row() {
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
/// Returns an empty list if the query succeeded but found no rows,
/// or `DatabaseError` if the query failed.
///
/// ## Example
///
/// ```gleam
/// case user.list(db) |> query.all_rows() {
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
