//// README: Index Management
////
//// Creates an index with a mapping and deletes an old index.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

// Create index with mapping
pub fn create_users_index(opensearch: Client) -> Result(String, String) {
  let mapping =
    json.object([
      #(
        "mappings",
        json.object([
          #(
            "properties",
            json.object([
              #("name", json.object([#("type", json.string("text"))])),
              #("email", json.object([#("type", json.string("keyword"))])),
            ]),
          ),
        ]),
      ),
    ])
  document.create_index(opensearch, "users", json.to_string(mapping))
}

// Delete index
pub fn delete_old_index(opensearch: Client) -> Result(String, String) {
  document.delete_index(opensearch, "old_index")
}
