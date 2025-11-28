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

pub fn match_url_only_creates_config_with_url_matching_enabled_test() {
  // Arrange & Act
  let config = matching.match_url_only()

  // Assert
  case config {
    matching.MatchingConfig(match_method, match_url, match_headers, match_body) -> {
      match_method |> should.equal(True)
      match_url |> should.equal(True)
      match_headers |> should.equal(False)
      match_body |> should.equal(False)
    }
  }
}

pub fn build_signature_with_url_only_matches_ignores_headers_and_body_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.equal(sig2)
}

pub fn build_signature_with_different_methods_creates_different_signatures_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_different_paths_creates_different_signatures_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_different_hosts_creates_different_signatures_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_port_includes_port_in_signature_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_query_includes_query_in_signature_test() {
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
  let config = matching.match_url_only()

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn requests_match_with_same_request_returns_true_test() {
  // Arrange
  let request = create_test_request()
  let config = matching.match_url_only()

  // Act
  let result = matching.requests_match(request, request, config)

  // Assert
  result |> should.equal(True)
}

pub fn requests_match_with_different_methods_returns_false_test() {
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
  let config = matching.match_url_only()

  // Act
  let result = matching.requests_match(request1, request2, config)

  // Assert
  result |> should.equal(False)
}

pub fn requests_match_with_different_paths_returns_false_test() {
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
  let config = matching.match_url_only()

  // Act
  let result = matching.requests_match(request1, request2, config)

  // Assert
  result |> should.equal(False)
}

pub fn build_signature_with_custom_config_respects_all_flags_test() {
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
  let config =
    matching.MatchingConfig(
      match_method: True,
      match_url: True,
      match_headers: True,
      match_body: True,
    )

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_headers_matching_includes_headers_test() {
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
  let config =
    matching.MatchingConfig(
      match_method: True,
      match_url: True,
      match_headers: True,
      match_body: False,
    )

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}

pub fn build_signature_with_body_matching_includes_body_test() {
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
  let config =
    matching.MatchingConfig(
      match_method: True,
      match_url: True,
      match_headers: False,
      match_body: True,
    )

  // Act
  let sig1 = matching.build_signature(request1, config)
  let sig2 = matching.build_signature(request2, config)

  // Assert
  sig1 |> should.not_equal(sig2)
}
