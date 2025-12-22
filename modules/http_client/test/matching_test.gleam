import dream_http_client/matching
import dream_http_client/recording
import gleam/http
import gleam/option
import gleeunit/should

fn create_test_request() -> recording.RecordedRequest {
  recording.RecordedRequest(
    method: http.Get,
    scheme: http.Https,
    host: "api.example.com",
    port: option.None,
    path: "/users",
    query: option.None,
    headers: [#("Authorization", "Bearer token")],
    body: "{}",
  )
}

pub fn request_key_with_method_and_url_ignores_headers_and_body_test() {
  // Arrange
  let request1 = create_test_request()
  let request2 =
    recording.RecordedRequest(
      method: request1.method,
      scheme: request1.scheme,
      host: request1.host,
      port: request1.port,
      path: request1.path,
      query: request1.query,
      headers: [#("Authorization", "Different token")],
      body: "{\"different\": true}",
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.equal(sig2)
}

pub fn request_key_includes_method_when_enabled_test() {
  // Arrange
  let request1 = create_test_request()
  let request2 =
    recording.RecordedRequest(
      method: http.Post,
      scheme: request1.scheme,
      host: request1.host,
      port: request1.port,
      path: request1.path,
      query: request1.query,
      headers: request1.headers,
      body: request1.body,
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_includes_path_when_url_enabled_test() {
  // Arrange
  let request1 = create_test_request()
  let request2 =
    recording.RecordedRequest(
      method: request1.method,
      scheme: request1.scheme,
      host: request1.host,
      port: request1.port,
      path: "/posts",
      query: request1.query,
      headers: request1.headers,
      body: request1.body,
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_includes_host_when_url_enabled_test() {
  // Arrange
  let request1 = create_test_request()
  let request2 =
    recording.RecordedRequest(
      method: request1.method,
      scheme: request1.scheme,
      host: "different.example.com",
      port: request1.port,
      path: request1.path,
      query: request1.query,
      headers: request1.headers,
      body: request1.body,
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_includes_port_when_url_enabled_test() {
  // Arrange
  let request1 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "",
    )
  let request2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.Some(8080),
      path: "/users",
      query: option.None,
      headers: [],
      body: "",
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_includes_query_when_url_enabled_test() {
  // Arrange
  let request1 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "",
    )
  let request2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.Some("page=1"),
      headers: [],
      body: "",
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_with_headers_and_body_enabled_changes_when_headers_and_body_change_test() {
  // Arrange
  let request1 = create_test_request()
  let request2 =
    recording.RecordedRequest(
      method: request1.method,
      scheme: request1.scheme,
      host: request1.host,
      port: request1.port,
      path: request1.path,
      query: request1.query,
      headers: [#("Authorization", "Different token")],
      body: "{\"different\": true}",
    )
  let key =
    matching.request_key(method: True, url: True, headers: True, body: True)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_with_headers_enabled_includes_headers_test() {
  // Arrange
  let request1 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [#("Authorization", "Token1")],
      body: "",
    )
  let request2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [#("Authorization", "Token2")],
      body: "",
    )
  let key =
    matching.request_key(method: True, url: True, headers: True, body: False)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn request_key_with_body_enabled_includes_body_test() {
  // Arrange
  let request1 =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "{\"name\": \"Alice\"}",
    )
  let request2 =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "{\"name\": \"Bob\"}",
    )
  let key =
    matching.request_key(method: True, url: True, headers: False, body: True)

  // Act
  let sig1 = key(request1)
  let sig2 = key(request2)

  // Assert
  sig1 |> should.not_equal(sig2)
}
