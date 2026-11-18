//// README: Searching
////
//// One search for each query builder.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import dream_opensearch/query

// Full-text search
pub fn search_by_name(opensearch: Client) -> Result(String, String) {
  let name_query = query.match("name", "Alice")
  document.search(opensearch, "users", name_query)
}

// Exact term match
pub fn search_by_status(opensearch: Client) -> Result(String, String) {
  let status_query = query.term("status", "active")
  document.search(opensearch, "users", status_query)
}

// Range query
pub fn search_by_age(opensearch: Client) -> Result(String, String) {
  let age_query = query.range("age", "18", "65")
  document.search(opensearch, "users", age_query)
}

// Match all
pub fn search_all(opensearch: Client) -> Result(String, String) {
  let all_query = query.match_all()
  document.search(opensearch, "users", all_query)
}
