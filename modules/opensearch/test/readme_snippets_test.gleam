//// Tests for the code blocks in this module's README.md.
////
//// Requests go to the one-shot server in `opensearch_test_server` on
//// 127.0.0.1 with a port from the operating system, not to a real
//// OpenSearch. The tests check the request each snippet sends and the result
//// it returns.

import dream_opensearch/client
import gleam/int
import gleeunit/should
import opensearch_test_server.{Respond}
import snippets/readme_bulk_operations
import snippets/readme_client_setup
import snippets/readme_custom_queries
import snippets/readme_index_management
import snippets/readme_indexing_documents
import snippets/readme_quick_start
import snippets/readme_searching

// ============================================================================
// Quick Start
// ============================================================================

pub fn quick_start_create_client_uses_localhost_9200_test() {
  // Act
  let opensearch = readme_quick_start.create_client()

  // Assert
  opensearch.base_url |> should.equal("http://localhost:9200")
}

pub fn quick_start_index_alice_sends_put_to_the_document_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(201, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_quick_start.index_alice(opensearch)

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("PUT", "/users/_doc/123"))
}

pub fn quick_start_index_alice_sends_the_user_as_json_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(201, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_quick_start.index_alice(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal("{\"name\":\"Alice\",\"email\":\"alice@example.com\"}")
}

pub fn quick_start_search_for_alice_sends_a_match_query_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_quick_start.search_for_alice(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  #(request.method, request.target, request.body)
  |> should.equal(#(
    "POST",
    "/users/_search",
    "{\"query\":{\"match\":{\"name\":\"Alice\"}}}",
  ))
}

pub fn quick_start_search_for_alice_returns_the_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "{\"hits\":{\"total\":1}}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = readme_quick_start.search_for_alice(opensearch)

  // Assert
  result |> should.equal(Ok("{\"hits\":{\"total\":1}}"))
}

pub fn quick_start_delete_alice_sends_delete_to_the_document_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_quick_start.delete_alice(opensearch)

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("DELETE", "/users/_doc/123"))
}

// ============================================================================
// Client Setup
// ============================================================================

pub fn client_setup_create_local_client_uses_localhost_9200_test() {
  // Act
  let opensearch = readme_client_setup.create_local_client()

  // Assert
  opensearch.base_url |> should.equal("http://localhost:9200")
}

pub fn client_setup_create_client_with_credentials_keeps_url_test() {
  // Act
  let opensearch = readme_client_setup.create_client_with_credentials()

  // Assert
  opensearch.base_url
  |> should.equal("https://user:pass@search.example.com:9200")
}

pub fn credentials_in_url_send_basic_authorization_header_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let port = opensearch_test_server.port(server)
  let opensearch =
    client.new("http://user:pass@127.0.0.1:" <> int.to_string(port))

  // Act
  let _ = readme_quick_start.search_for_alice(opensearch)

  // Assert: base64 of "user:pass"
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.header_values("authorization")
  |> should.equal(["Basic dXNlcjpwYXNz"])
}

// ============================================================================
// Indexing Documents
// ============================================================================

pub fn index_user_sends_the_user_with_age_as_json_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(201, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_indexing_documents.index_user(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal(
    "{\"name\":\"Alice\",\"email\":\"alice@example.com\",\"age\":30}",
  )
}

pub fn index_user_reports_success_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(201, "{\"result\":\"created\"}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = readme_indexing_documents.index_user(opensearch)

  // Assert
  result |> should.equal("Indexed successfully")
}

pub fn index_user_reports_the_error_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(400, "{\"error\":\"bad request\"}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = readme_indexing_documents.index_user(opensearch)

  // Assert
  result |> should.equal("Error: {\"error\":\"bad request\"}")
}

// ============================================================================
// Searching
// ============================================================================

pub fn search_by_name_sends_a_match_query_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_searching.search_by_name(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal("{\"query\":{\"match\":{\"name\":\"Alice\"}}}")
}

pub fn search_by_status_sends_a_term_query_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_searching.search_by_status(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal("{\"query\":{\"term\":{\"status\":\"active\"}}}")
}

pub fn search_by_age_sends_a_range_query_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_searching.search_by_age(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal(
    "{\"query\":{\"range\":{\"age\":{\"gte\":\"18\",\"lte\":\"65\"}}}}",
  )
}

pub fn search_all_sends_a_match_all_query_to_the_search_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_searching.search_all(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  #(request.method, request.target, request.body)
  |> should.equal(#("POST", "/users/_search", "{\"query\":{\"match_all\":{}}}"))
}

// ============================================================================
// Custom Queries
// ============================================================================

pub fn search_active_users_named_alice_sends_a_bool_query_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_custom_queries.search_active_users_named_alice(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal(
    "{\"query\":{\"bool\":{\"must\":[{\"match\":{\"name\":\"Alice\"}}],\"filter\":[{\"term\":{\"status\":\"active\"}}]}}}",
  )
}

// ============================================================================
// Index Management
// ============================================================================

pub fn create_users_index_sends_the_mapping_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_index_management.create_users_index(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  #(request.method, request.target, request.body)
  |> should.equal(#(
    "PUT",
    "/users",
    "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"},\"email\":{\"type\":\"keyword\"}}}}",
  ))
}

pub fn delete_old_index_sends_delete_to_the_index_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_index_management.delete_old_index(opensearch)

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("DELETE", "/old_index"))
}

// ============================================================================
// Bulk Operations
// ============================================================================

pub fn bulk_index_users_sends_ndjson_to_the_bulk_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = readme_bulk_operations.bulk_index_users(opensearch)

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  #(request.method, request.target, request.body)
  |> should.equal(#(
    "POST",
    "/_bulk",
    "{ \"index\": { \"_index\": \"users\", \"_id\": \"1\" } }\n"
      <> "{ \"name\": \"Alice\", \"email\": \"alice@example.com\" }\n"
      <> "{ \"index\": { \"_index\": \"users\", \"_id\": \"2\" } }\n"
      <> "{ \"name\": \"Bob\", \"email\": \"bob@example.com\" }\n",
  ))
}
