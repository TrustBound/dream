import dream_http_client/client
import gleam/http
import gleam/list
import gleam/option
import gleeunit/should

pub fn method_sets_request_method_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.method(request, http.Post)

  // Assert
  client.get_method(updated) |> should.equal(http.Post)
}

pub fn scheme_sets_request_scheme_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.scheme(request, http.Http)

  // Assert
  client.get_scheme(updated) |> should.equal(http.Http)
}

pub fn host_sets_request_host_test() {
  // Arrange
  let request = client.new
  let host_value = "example.com"

  // Act
  let updated = client.host(request, host_value)

  // Assert
  client.get_host(updated) |> should.equal(host_value)
}

pub fn port_sets_request_port_test() {
  // Arrange
  let request = client.new
  let port_value = 8080

  // Act
  let updated = client.port(request, port_value)

  // Assert
  client.get_port(updated) |> should.equal(option.Some(port_value))
}

pub fn path_sets_request_path_test() {
  // Arrange
  let request = client.new
  let path_value = "/api/users"

  // Act
  let updated = client.path(request, path_value)

  // Assert
  client.get_path(updated) |> should.equal(path_value)
}

pub fn query_sets_request_query_test() {
  // Arrange
  let request = client.new
  let query_value = "name=value"

  // Act
  let updated = client.query(request, query_value)

  // Assert
  client.get_query(updated) |> should.equal(option.Some(query_value))
}

pub fn headers_sets_request_headers_test() {
  // Arrange
  let request = client.new
  let headers_value = [#("Authorization", "Bearer token")]

  // Act
  let updated = client.headers(request, headers_value)

  // Assert
  client.get_headers(updated) |> list.length() |> should.equal(1)
}

pub fn body_sets_request_body_test() {
  // Arrange
  let request = client.new
  let body_value = "{\"key\":\"value\"}"

  // Act
  let updated = client.body(request, body_value)

  // Assert
  client.get_body(updated) |> should.equal(body_value)
}

pub fn timeout_sets_request_timeout_test() {
  // Arrange
  let request = client.new
  let timeout_value = 60_000

  // Act
  let updated = client.timeout(request, timeout_value)

  // Assert
  client.get_timeout(updated) |> should.equal(option.Some(timeout_value))
}

pub fn add_header_adds_header_to_request_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.add_header(request, "X-Custom", "value")

  // Assert
  let headers = client.get_headers(updated)
  list.length(headers) |> should.equal(1)
  case headers {
    [#(name, value), ..] -> {
      name |> should.equal("X-Custom")
      value |> should.equal("value")
    }
    [] -> should.fail()
  }
}
