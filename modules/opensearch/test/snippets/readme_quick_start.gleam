//// README: Quick Start
////
//// Creates a client, then indexes, searches for and deletes one user.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import dream_opensearch/query
import gleam/json

// Create client
pub fn create_client() -> Client {
  client.new("http://localhost:9200")
}

// Index a document
pub fn index_alice(opensearch: Client) -> Result(String, String) {
  let user =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
    ])
  document.index(opensearch, "users", "123", json.to_string(user))
}

// Search documents
pub fn search_for_alice(opensearch: Client) -> Result(String, String) {
  let search_query = query.match("name", "Alice")
  document.search(opensearch, "users", search_query)
}

// Delete document
pub fn delete_alice(opensearch: Client) -> Result(String, String) {
  document.delete(opensearch, "users", "123")
}
