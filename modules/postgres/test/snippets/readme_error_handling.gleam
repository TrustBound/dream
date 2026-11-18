//// README: Error Handling
////
//// Handles both QueryError variants.

import dream_postgres/query

pub fn explain_query_error(error: query.QueryError) -> String {
  case error {
    // Query succeeded but no rows
    query.NotFound -> "The query returned no rows"
    // Query failed (connection, SQL, etc.)
    query.DatabaseError -> "The query failed"
  }
}
