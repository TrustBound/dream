//// OpenSearch document operations
////
//// This module provides high-level functions for common OpenSearch operations:
//// indexing documents, searching, deleting, and managing indices.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_opensearch/client
//// import dream_opensearch/document
//// import gleam/json
////
//// let client = client.new("http://localhost:9200")
////
//// // Index a document
//// let doc = json.object([
////   #("name", json.string("Alice")),
////   #("email", json.string("alice@example.com")),
//// ])
//// document.index(client, "users", "123", json.to_string(doc))
//// ```
////
//// ## JSON Format
////
//// All document operations expect JSON strings. Use `gleam/json` to build
//// JSON objects and convert them to strings with `json.to_string()`.

import dream_opensearch/client.{type Client}
import gleam/http

/// Index a document in OpenSearch
///
/// Creates or updates a document in the specified index. If a document with
/// the same ID already exists, it will be replaced.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `index_name`: The name of the index (e.g., "users", "products")
/// - `document_id`: The unique document ID
/// - `document_json`: The document as a JSON string
///
/// ## Returns
///
/// - `Ok(String)`: The OpenSearch response as JSON string
/// - `Error(String)`: An error message if the operation failed
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import gleam/json
///
/// let doc = json.object([
///   #("name", json.string("Alice")),
///   #("email", json.string("alice@example.com")),
/// ])
///
/// case document.index(client, "users", "123", json.to_string(doc)) {
///   Ok(response) -> io.println("Indexed successfully")
///   Error(msg) -> io.println("Error: " <> msg)
/// }
/// ```
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
///
/// Performs a search query against the specified index. The query should be
/// a valid OpenSearch query JSON string. Use `dream_opensearch/query` helpers
/// to build queries, or construct the JSON manually.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `index_name`: The name of the index to search
/// - `query_json`: The search query as a JSON string
///
/// ## Returns
///
/// - `Ok(String)`: The search results as JSON string
/// - `Error(String)`: An error message if the search failed
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import dream_opensearch/query
///
/// let query = query.match("name", "Alice")
/// case document.search(client, "users", query) {
///   Ok(results) -> process_results(results)
///   Error(msg) -> handle_error(msg)
/// }
/// ```
pub fn search(
  client: Client,
  index_name: String,
  query_json: String,
) -> Result(String, String) {
  let path = "/" <> index_name <> "/_search"
  client.send_request(client, http.Post, path, query_json)
}

/// Delete a document from an index
///
/// Removes a document from the specified index by its ID.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `index_name`: The name of the index
/// - `document_id`: The ID of the document to delete
///
/// ## Returns
///
/// - `Ok(String)`: The OpenSearch response as JSON string
/// - `Error(String)`: An error message if the deletion failed
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
///
/// case document.delete(client, "users", "123") {
///   Ok(_) -> io.println("Document deleted")
///   Error(msg) -> io.println("Error: " <> msg)
/// }
/// ```
pub fn delete(
  client: Client,
  index_name: String,
  document_id: String,
) -> Result(String, String) {
  let path = "/" <> index_name <> "/_doc/" <> document_id
  client.send_request(client, http.Delete, path, "")
}

/// Create an index with mapping
///
/// Creates a new index with the specified mapping (schema). The mapping
/// defines the fields and their types for documents in the index.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `index_name`: The name of the index to create
/// - `mapping_json`: The index mapping as a JSON string
///
/// ## Returns
///
/// - `Ok(String)`: The OpenSearch response as JSON string
/// - `Error(String)`: An error message if creation failed (e.g., index already exists)
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
/// import gleam/json
///
/// let mapping = json.object([
///   #("mappings", json.object([
///     #("properties", json.object([
///       #("name", json.object([#("type", json.string("text"))])),
///       #("email", json.object([#("type", json.string("keyword"))])),
///     ])),
///   ])),
/// ])
///
/// document.create_index(client, "users", json.to_string(mapping))
/// ```
pub fn create_index(
  client: Client,
  index_name: String,
  mapping_json: String,
) -> Result(String, String) {
  let path = "/" <> index_name
  client.send_request(client, http.Put, path, mapping_json)
}

/// Delete an index
///
/// Permanently deletes an index and all its documents. This operation cannot
/// be undone.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `index_name`: The name of the index to delete
///
/// ## Returns
///
/// - `Ok(String)`: The OpenSearch response as JSON string
/// - `Error(String)`: An error message if deletion failed (e.g., index doesn't exist)
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
///
/// case document.delete_index(client, "old_index") {
///   Ok(_) -> io.println("Index deleted")
///   Error(msg) -> io.println("Error: " <> msg)
/// }
/// ```
pub fn delete_index(
  client: Client,
  index_name: String,
) -> Result(String, String) {
  let path = "/" <> index_name
  client.send_request(client, http.Delete, path, "")
}

/// Bulk index documents
///
/// Indexes multiple documents in a single request using OpenSearch's bulk API.
/// The body must be in NDJSON (newline-delimited JSON) format, where each line
/// is a JSON object.
///
/// ## Parameters
///
/// - `client`: The OpenSearch client
/// - `ndjson`: The bulk request body in NDJSON format
///
/// ## Returns
///
/// - `Ok(String)`: The OpenSearch response as JSON string
/// - `Error(String)`: An error message if the bulk operation failed
///
/// ## Example
///
/// ```gleam
/// import dream_opensearch/document
///
/// // NDJSON format: action and document on alternating lines
/// let ndjson = "{ \"index\": { \"_index\": \"users\", \"_id\": \"1\" } }\n"
///   <> "{ \"name\": \"Alice\", \"email\": \"alice@example.com\" }\n"
///   <> "{ \"index\": { \"_index\": \"users\", \"_id\": \"2\" } }\n"
///   <> "{ \"name\": \"Bob\", \"email\": \"bob@example.com\" }\n"
///
/// document.bulk(client, ndjson)
/// ```
pub fn bulk(client: Client, ndjson: String) -> Result(String, String) {
  let path = "/_bulk"
  client.send_request(client, http.Post, path, ndjson)
}
