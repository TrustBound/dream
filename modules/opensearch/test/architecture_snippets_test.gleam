//// Tests for the dream_opensearch snippet in docs/reference/architecture.md.
////
//// Requests go to the one-shot server in `opensearch_test_server`, not to a
//// real OpenSearch.

import dream_opensearch/client
import gleeunit/should
import opensearch_test_server.{Respond}
import snippets/architecture_opensearch

pub fn create_client_uses_localhost_9200_test() {
  // Arrange
  let opensearch = architecture_opensearch.create_client()

  // Act
  let base_url = opensearch.base_url

  // Assert
  base_url |> should.equal("http://localhost:9200")
}

pub fn index_log_entry_sends_put_to_the_document_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(201, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = architecture_opensearch.index_log_entry(opensearch, "Started")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("PUT", "/logs/_doc/doc-id-123"))
}

pub fn index_log_entry_sends_the_message_as_json_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(201, "{}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = architecture_opensearch.index_log_entry(opensearch, "Started")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("{\"message\":\"Started\"}")
}

pub fn index_log_entry_returns_the_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(201, "{\"result\":\"created\"}"))
  let opensearch = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = architecture_opensearch.index_log_entry(opensearch, "Started")

  // Assert
  result |> should.equal(Ok("{\"result\":\"created\"}"))
}
