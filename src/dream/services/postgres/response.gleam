//// Response helpers for PostgreSQL query results
////
//// This module provides convenience functions for converting pog query results
//// into HTTP responses, handling common patterns like single row, multiple rows,
//// and success/failure.

import dream/core/http/statuses.{
  internal_server_error_status, not_found_status, ok_status,
}
import dream/core/http/transaction.{type Response, json_response, text_response}
import gleam/json
import gleam/list
import pog

/// Extract a single row from a query result and encode to JSON response
/// Returns 404 if no rows found, 500 on database error
pub fn one_row(
  query_result: Result(pog.Returned(row_type), pog.QueryError),
  encode: fn(row_type) -> json.Json,
) -> Response {
  case query_result {
    Ok(db_result) ->
      case list.first(db_result.rows) {
        Ok(row) -> json_response(ok_status(), json.to_string(encode(row)))
        Error(_) -> text_response(not_found_status(), "Not found")
      }
    Error(_) -> text_response(internal_server_error_status(), "Database error")
  }
}

/// Extract all rows from a query result and encode to JSON array response
/// Returns empty array if no rows found, 500 on database error
pub fn many_rows(
  query_result: Result(pog.Returned(row_type), pog.QueryError),
  encode: fn(row_type) -> json.Json,
) -> Response {
  case query_result {
    Ok(db_result) -> {
      let json_array =
        db_result.rows
        |> list.map(encode)
        |> json.array(from: _, of: fn(x) { x })
      json_response(ok_status(), json.to_string(json_array))
    }
    Error(_) -> text_response(internal_server_error_status(), "Database error")
  }
}

/// Return success/error response for operations that don't return data
/// Returns 200 on success, 500 on database error
pub fn success(
  query_result: Result(pog.Returned(_), pog.QueryError),
) -> Response {
  case query_result {
    Ok(_) -> text_response(ok_status(), "Success")
    Error(_) -> text_response(internal_server_error_status(), "Database error")
  }
}
