//// Tests for the code blocks in the dream_mock_server README.
////
//// Each test runs a snippet and checks the exact result.

import dream/context.{EmptyContext}
import dream/http/request.{Get, Http, Http1, Request, Text}
import dream/http/response.{Stream, Text as TextBody}
import dream/router.{EmptyServices}
import dream_mock_server/config.{Exact, MockRoute, Prefix}
import dream_mock_server/server
import gleam/int
import gleam/option.{None, Some}
import gleam/yielder
import gleeunit/should
import snippets/config_mode_method_specific
import snippets/config_mode_ordering
import snippets/config_mode_prefix
import snippets/http_helper
import snippets/non_streaming_technique
import snippets/port
import snippets/programmatic_control
import snippets/programmatic_mode
import snippets/streaming_technique

fn base_url(port: Int) -> String {
  "http://localhost:" <> int.to_string(port)
}

fn get_text(base: String) -> Result(#(Int, String), String) {
  http_helper.get(base <> "/text")
}

fn create_request(path: String) -> request.Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: None,
    port: None,
    remote_address: None,
    body: Text(""),
    headers: [],
    cookies: [],
    content_type: None,
    content_length: None,
  )
}

pub fn with_mock_server_runs_the_test_body_against_the_server_test() {
  // Arrange
  let port = port.free_port()

  // Act
  let outcome = programmatic_mode.with_mock_server(port, get_text)

  // Assert
  outcome |> should.equal(Ok(Ok(#(200, "Hello, World!"))))
}

pub fn chat_completion_routes_returns_one_prefix_route_test() {
  // Act
  let routes = config_mode_prefix.chat_completion_routes()

  // Assert
  routes
  |> should.equal([
    MockRoute(
      path: "/v1/chat/completions",
      path_match: Prefix,
      method: None,
      status: 200,
      body: "{\"choices\":[{\"message\":{\"content\":\"\"}}]}",
    ),
  ])
}

pub fn start_chat_mock_matches_a_longer_path_by_prefix_test() {
  // Arrange
  let port = port.free_port()
  let handle = config_mode_prefix.start_chat_mock(port) |> should.be_ok()

  // Act
  let response =
    http_helper.get(base_url(port) <> "/v1/chat/completions/stream")
  server.stop(handle)

  // Assert
  response
  |> should.equal(
    Ok(#(200, "{\"choices\":[{\"message\":{\"content\":\"\"}}]}")),
  )
}

pub fn resource_routes_answers_get_with_200_test() {
  // Arrange
  let port = port.free_port()
  let handle =
    server.start_with_config(
      port,
      config_mode_method_specific.resource_routes(),
    )
    |> should.be_ok()

  // Act
  let response = http_helper.get(base_url(port) <> "/resource")
  server.stop(handle)

  // Assert
  response |> should.equal(Ok(#(200, "{\"ok\":true}")))
}

pub fn resource_routes_answers_post_with_201_test() {
  // Arrange
  let port = port.free_port()
  let handle =
    server.start_with_config(
      port,
      config_mode_method_specific.resource_routes(),
    )
    |> should.be_ok()

  // Act
  let response = http_helper.post(base_url(port) <> "/resource", "")
  server.stop(handle)

  // Assert
  response |> should.equal(Ok(#(201, "{\"created\":true}")))
}

pub fn api_routes_puts_the_exact_route_first_test() {
  // Act
  let routes = config_mode_ordering.api_routes()

  // Assert
  routes
  |> should.equal([
    MockRoute("/api/special", Exact, None, 200, "special"),
    MockRoute("/api", Prefix, None, 200, "general"),
  ])
}

pub fn api_routes_sends_the_specific_path_to_the_exact_route_test() {
  // Arrange
  let port = port.free_port()
  let handle =
    server.start_with_config(port, config_mode_ordering.api_routes())
    |> should.be_ok()

  // Act
  let response = http_helper.get(base_url(port) <> "/api/special")
  server.stop(handle)

  // Assert
  response |> should.equal(Ok(#(200, "special")))
}

pub fn api_routes_sends_other_paths_to_the_prefix_route_test() {
  // Arrange
  let port = port.free_port()
  let handle =
    server.start_with_config(port, config_mode_ordering.api_routes())
    |> should.be_ok()

  // Act
  let response = http_helper.get(base_url(port) <> "/api/other")
  server.stop(handle)

  // Assert
  response |> should.equal(Ok(#(200, "general")))
}

pub fn fetch_text_starts_uses_and_stops_the_server_test() {
  // Arrange
  let port = port.free_port()

  // Act
  let response = programmatic_control.fetch_text(port)

  // Assert
  response |> should.equal(Ok(#(200, "Hello, World!")))
}

pub fn stream_fast_streams_ten_chunks_test() {
  // Arrange
  let request = create_request("/stream/fast")

  // Act
  let response =
    streaming_technique.stream_fast(request, EmptyContext, EmptyServices)

  // Assert
  let assert Stream(stream) = response.body
  #(response.status, response.content_type, yielder.to_list(stream))
  |> should.equal(
    #(200, Some("text/plain"), [
      <<"Chunk 1\n":utf8>>,
      <<"Chunk 2\n":utf8>>,
      <<"Chunk 3\n":utf8>>,
      <<"Chunk 4\n":utf8>>,
      <<"Chunk 5\n":utf8>>,
      <<"Chunk 6\n":utf8>>,
      <<"Chunk 7\n":utf8>>,
      <<"Chunk 8\n":utf8>>,
      <<"Chunk 9\n":utf8>>,
      <<"Chunk 10\n":utf8>>,
    ]),
  )
}

pub fn get_returns_the_method_and_path_as_json_test() {
  // Arrange
  let request = create_request("/get")

  // Act
  let response =
    non_streaming_technique.get(request, EmptyContext, EmptyServices)

  // Assert
  #(response.status, response.body)
  |> should.equal(#(200, TextBody("{\"method\":\"GET\",\"url\":\"/get\"}")))
}
