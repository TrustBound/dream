//// Black-box tests for `dream_opensearch/document`.
////
//// Requests go to a one-shot server on 127.0.0.1 (see
//// `opensearch_test_server`), which records the request exactly as it
//// arrives and answers with the status and body each test chooses.

import dream_opensearch/client
import dream_opensearch/document
import gleeunit/should
import opensearch_test_server.{Respond}

// ============================================================================
// index
// ============================================================================

pub fn index_sends_put_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.index(os_client, "users", "123", "{\"name\":\"Alice\"}")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("PUT", "/users/_doc/123"))
}

pub fn index_sends_given_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.index(os_client, "users", "123", "{\"name\":\"Alice\"}")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("{\"name\":\"Alice\"}")
}

pub fn index_with_201_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(201, "{\"result\":\"created\"}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.index(os_client, "users", "123", "{\"name\":\"Alice\"}")

  // Assert
  result |> should.equal(Ok("{\"result\":\"created\"}"))
}

pub fn index_with_400_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      400,
      "{\"error\":{\"type\":\"mapper_parsing_exception\"},\"status\":400}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.index(os_client, "users", "123", "{\"name\":\"Alice\"}")

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"mapper_parsing_exception\"},\"status\":400}",
  ))
}

pub fn index_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result = document.index(os_client, "users", "123", "{\"name\":\"Alice\"}")

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}

// ============================================================================
// search
// ============================================================================

pub fn search_sends_post_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.search(os_client, "users", "{\"query\":{\"match_all\":{}}}")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("POST", "/users/_search"))
}

pub fn search_sends_given_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.search(os_client, "users", "{\"query\":{\"match_all\":{}}}")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("{\"query\":{\"match_all\":{}}}")
}

pub fn search_with_200_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      200,
      "{\"hits\":{\"total\":{\"value\":0},\"hits\":[]}}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.search(os_client, "users", "{\"query\":{\"match_all\":{}}}")

  // Assert
  result |> should.equal(Ok("{\"hits\":{\"total\":{\"value\":0},\"hits\":[]}}"))
}

pub fn search_with_404_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      404,
      "{\"error\":{\"type\":\"index_not_found_exception\"},\"status\":404}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.search(os_client, "users", "{\"query\":{\"match_all\":{}}}")

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"index_not_found_exception\"},\"status\":404}",
  ))
}

pub fn search_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result =
    document.search(os_client, "users", "{\"query\":{\"match_all\":{}}}")

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}

// ============================================================================
// delete
// ============================================================================

pub fn delete_sends_delete_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.delete(os_client, "users", "123")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("DELETE", "/users/_doc/123"))
}

pub fn delete_sends_empty_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.delete(os_client, "users", "123")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("")
}

pub fn delete_with_200_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "{\"result\":\"deleted\"}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.delete(os_client, "users", "123")

  // Assert
  result |> should.equal(Ok("{\"result\":\"deleted\"}"))
}

pub fn delete_with_404_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      404,
      "{\"_id\":\"123\",\"result\":\"not_found\"}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.delete(os_client, "users", "123")

  // Assert
  result |> should.equal(Error("{\"_id\":\"123\",\"result\":\"not_found\"}"))
}

pub fn delete_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result = document.delete(os_client, "users", "123")

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}

// ============================================================================
// create_index
// ============================================================================

pub fn create_index_sends_put_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ =
    document.create_index(
      os_client,
      "users",
      "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
    )

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("PUT", "/users"))
}

pub fn create_index_sends_given_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ =
    document.create_index(
      os_client,
      "users",
      "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
    )

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal(
    "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
  )
}

pub fn create_index_with_200_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      200,
      "{\"acknowledged\":true,\"index\":\"users\"}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.create_index(
      os_client,
      "users",
      "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
    )

  // Assert
  result |> should.equal(Ok("{\"acknowledged\":true,\"index\":\"users\"}"))
}

pub fn create_index_with_400_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      400,
      "{\"error\":{\"type\":\"resource_already_exists_exception\"},\"status\":400}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.create_index(
      os_client,
      "users",
      "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
    )

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"resource_already_exists_exception\"},\"status\":400}",
  ))
}

pub fn create_index_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result =
    document.create_index(
      os_client,
      "users",
      "{\"mappings\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}",
    )

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}

// ============================================================================
// delete_index
// ============================================================================

pub fn delete_index_sends_delete_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.delete_index(os_client, "old_index")

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("DELETE", "/old_index"))
}

pub fn delete_index_sends_empty_body_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ = document.delete_index(os_client, "old_index")

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body |> should.equal("")
}

pub fn delete_index_with_200_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(200, "{\"acknowledged\":true}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.delete_index(os_client, "old_index")

  // Assert
  result |> should.equal(Ok("{\"acknowledged\":true}"))
}

pub fn delete_index_with_404_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      404,
      "{\"error\":{\"type\":\"index_not_found_exception\"},\"status\":404}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result = document.delete_index(os_client, "old_index")

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"index_not_found_exception\"},\"status\":404}",
  ))
}

pub fn delete_index_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result = document.delete_index(os_client, "old_index")

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}

// ============================================================================
// bulk
// ============================================================================

pub fn bulk_sends_post_to_expected_path_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ =
    document.bulk(
      os_client,
      "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
    )

  // Assert
  opensearch_test_server.await_request(server)
  |> should.be_ok
  |> opensearch_test_server.request_line
  |> should.equal(#("POST", "/_bulk"))
}

pub fn bulk_sends_given_body_unchanged_test() {
  // Arrange
  let server = opensearch_test_server.start(Respond(200, "{}"))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let _ =
    document.bulk(
      os_client,
      "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
    )

  // Assert
  let request = opensearch_test_server.await_request(server) |> should.be_ok
  request.body
  |> should.equal(
    "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
  )
}

pub fn bulk_with_200_returns_ok_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      200,
      "{\"took\":3,\"errors\":false,\"items\":[]}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.bulk(
      os_client,
      "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
    )

  // Assert
  result |> should.equal(Ok("{\"took\":3,\"errors\":false,\"items\":[]}"))
}

pub fn bulk_with_400_returns_error_response_body_test() {
  // Arrange
  let server =
    opensearch_test_server.start(Respond(
      400,
      "{\"error\":{\"type\":\"illegal_argument_exception\"},\"status\":400}",
    ))
  let os_client = client.new(opensearch_test_server.base_url(server))

  // Act
  let result =
    document.bulk(
      os_client,
      "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
    )

  // Assert
  result
  |> should.equal(Error(
    "{\"error\":{\"type\":\"illegal_argument_exception\"},\"status\":400}",
  ))
}

pub fn bulk_when_nothing_listens_returns_connection_error_test() {
  // Arrange
  let os_client = client.new(opensearch_test_server.unreachable_base_url())

  // Act
  let result =
    document.bulk(
      os_client,
      "{\"index\":{\"_index\":\"users\",\"_id\":\"1\"}}\n{\"name\":\"Alice\"}\n",
    )

  // Assert
  result |> should.equal(Error("Connection failed: Connection refused"))
}
