//// OpenSearch document operations

import dream_opensearch/client.{type Client}
import gleam/http
import gleam/result

/// Index a document in OpenSearch
pub fn index(
  client: Client,
  index_name: String,
  document_id: String,
  document_json: String,
) -> Result(String, String) {
  let path = "/" <> index_name <> "/_doc/" <> document_id
  client.send_request(client, http.Put, path, document_json)
}

/// Search documents in an index
pub fn search(
  client: Client,
  index_name: String,
  query_json: String,
) -> Result(String, String) {
  let path = "/" <> index_name <> "/_search"
  client.send_request(client, http.Post, path, query_json)
}

/// Delete a document from an index
pub fn delete(
  client: Client,
  index_name: String,
  document_id: String,
) -> Result(String, String) {
  let path = "/" <> index_name <> "/_doc/" <> document_id
  client.send_request(client, http.Delete, path, "")
}

/// Create an index with mapping
pub fn create_index(
  client: Client,
  index_name: String,
  mapping_json: String,
) -> Result(String, String) {
  let path = "/" <> index_name
  client.send_request(client, http.Put, path, mapping_json)
}

/// Delete an index
pub fn delete_index(client: Client, index_name: String) -> Result(String, String) {
  let path = "/" <> index_name
  client.send_request(client, http.Delete, path, "")
}

/// Bulk index documents
pub fn bulk(client: Client, ndjson: String) -> Result(String, String) {
  let path = "/_bulk"
  client.send_request(client, http.Post, path, ndjson)
}

