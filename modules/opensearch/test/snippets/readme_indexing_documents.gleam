//// README: Indexing Documents
////
//// Indexes one user and reports the result.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn index_user(opensearch: Client) -> String {
  let user =
    json.object([
      #("name", json.string("Alice")),
      #("email", json.string("alice@example.com")),
      #("age", json.int(30)),
    ])

  case document.index(opensearch, "users", "123", json.to_string(user)) {
    Ok(_response) -> "Indexed successfully"
    Error(message) -> "Error: " <> message
  }
}
