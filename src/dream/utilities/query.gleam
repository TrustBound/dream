//// Database query result helpers for extracting rows

import gleam/list
import pog

/// Query error types
pub type QueryError {
  NotFound
  DatabaseError
}

/// Extract first row from query result
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

/// Extract all rows from query result
pub fn all_rows(
  result: Result(pog.Returned(row), pog.QueryError),
) -> Result(List(row), QueryError) {
  case result {
    Ok(db_result) -> Ok(db_result.rows)
    Error(_) -> Error(DatabaseError)
  }
}

