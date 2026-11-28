//// Architecture reference: dream_opensearch
////
//// Creates a client and indexes one log document.

import dream_opensearch/client.{type Client}
import dream_opensearch/document
import gleam/json

pub fn create_client() -> Client {
  client.new("http://localhost:9200")
}

pub fn index_log_entry(
  opensearch: Client,
  message: String,
) -> Result(String, String) {
  let document_json =
    json.object([#("message", json.string(message))])
    |> json.to_string()
  document.index(opensearch, "logs", "doc-id-123", document_json)
}
