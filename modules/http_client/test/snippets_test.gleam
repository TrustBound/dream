//// Tests for the code blocks in the dream_http_client README, and for the
//// other snippets in test/snippets/.
////
//// The requests go to dream_mock_server, which the test main starts on
//// localhost:9876.

import dream_http_client/client.{type HttpResponse, type SendError}
import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/option
import gleam/result
import gleeunit/should
import simplifile
import snippets/blocking_request
import snippets/blocking_send
import snippets/matching_config
import snippets/per_request_settings
import snippets/post_json
import snippets/recording_ambiguous_match
import snippets/recording_basic
import snippets/recording_playback
import snippets/recording_response_transformer
import snippets/recording_start_stream
import snippets/recording_stream_yielder
import snippets/recording_transformer
import snippets/request_builder
import snippets/stream_cancel
import snippets/stream_messages_basic
import snippets/stream_yielder_basic
import snippets/timeout_config
import snippets/transport_config_example

fn status_and_body(response: HttpResponse) -> #(Int, String) {
  #(response.status, response.body)
}

fn to_status_and_body(
  result: Result(HttpResponse, error),
) -> Result(#(Int, String), error) {
  result.map(result, status_and_body)
}

fn status_of_send_result(result: Result(HttpResponse, SendError)) -> Int {
  case result {
    Ok(response) -> response.status
    Error(client.ResponseError(response: response)) -> response.status
    Error(client.RequestError(error: _)) -> 0
  }
}

fn text_request(
  headers: List(#(String, String)),
  body: String,
) -> recording.RecordedRequest {
  recording.RecordedRequest(
    method: http.Get,
    scheme: http.Http,
    host: "localhost",
    port: option.Some(9876),
    path: "/text",
    query: option.None,
    headers: headers,
    body: body,
  )
}

fn fresh_directory(path: String) -> String {
  let _ = simplifile.delete(path)
  path
}

// README: Quick Start

pub fn simple_get_returns_the_text_endpoint_test() {
  // Act
  let result = blocking_request.simple_get()

  // Assert
  result
  |> to_status_and_body
  |> should.equal(Ok(#(200, "Hello, World!")))
}

// README: Blocking - send()

pub fn fetch_text_returns_the_body_test() {
  // Act
  let result = blocking_send.fetch_text()

  // Assert
  result |> should.equal(Ok("Hello, World!"))
}

// README: Yielder Streaming - stream_yielder()

pub fn count_stream_bytes_counts_all_ten_chunks_test() {
  // Act
  let result = stream_yielder_basic.count_stream_bytes()

  // Assert
  // "Chunk 1\n" to "Chunk 9\n" are 8 bytes each, "Chunk 10\n" is 9 bytes
  result |> should.equal(Ok(81))
}

// README: Process-Based Streaming - start_stream()

pub fn stream_and_print_completes_test() {
  // Act
  let result = stream_messages_basic.stream_and_print()

  // Assert
  result |> should.equal(Ok(Nil))
}

// README: Per-Request Settings

pub fn fetch_with_connect_timeout_returns_the_text_endpoint_test() {
  // Act
  let result = per_request_settings.fetch_with_connect_timeout()

  // Assert
  result
  |> to_status_and_body
  |> should.equal(Ok(#(200, "Hello, World!")))
}

pub fn fetch_without_redirect_returns_the_redirect_status_test() {
  // Act
  let result = per_request_settings.fetch_without_redirect()

  // Assert
  result |> status_of_send_result |> should.equal(302)
}

// README: Transport Settings

pub fn configure_high_concurrency_applies_the_config_test() {
  // Act
  let result = transport_config_example.configure_high_concurrency()
  client.configure_transport(client.transport_config())

  // Assert
  result |> should.equal(Nil)
}

// README: Recording & Playback, Quick Example

pub fn record_text_returns_the_real_response_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_recording_basic_record")

  // Act
  let result = recording_basic.record_text(directory)
  let _ = simplifile.delete(directory)

  // Assert
  result
  |> to_status_and_body
  |> should.equal(Ok(#(200, "Hello, World!")))
}

pub fn play_back_text_returns_the_recorded_response_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_recording_basic_playback")
  let _ = recording_basic.record_text(directory)

  // Act
  let result = recording_basic.play_back_text(directory)
  let _ = simplifile.delete(directory)

  // Assert
  result
  |> to_status_and_body
  |> should.equal(Ok(#(200, "Hello, World!")))
}

// README: Use Cases, Testing

pub fn fetch_recorded_text_returns_the_fixture_response_test() {
  // Arrange
  let playback_recorder =
    recording_playback.start_api_playback() |> should.be_ok()

  // Act
  let result = recording_playback.fetch_recorded_text(playback_recorder)
  let _ = recorder.stop(playback_recorder)

  // Assert
  result
  |> to_status_and_body
  |> should.equal(Ok(#(200, "Recorded text from the fixture")))
}

// README: Request Matching

pub fn method_and_url_key_ignores_headers_and_body_test() {
  // Arrange
  let request_key = matching_config.method_and_url_key()
  let first_request = text_request([#("Authorization", "Bearer one")], "a")
  let second_request = text_request([#("Authorization", "Bearer two")], "b")

  // Act
  let keys = #(request_key(first_request), request_key(second_request))

  // Assert
  keys
  |> should.equal(#(request_key(first_request), request_key(first_request)))
}

pub fn start_playback_finds_a_recording_with_other_headers_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_matching_config")
  let recorded_request = text_request([#("Authorization", "Bearer one")], "a")
  let saved =
    recording.Recording(
      request: recorded_request,
      response: recording.BlockingResponse(status: 200, headers: [], body: "ok"),
    )
  let request_key = matching_config.method_and_url_key()
  let _ =
    storage.save_recording_immediately(
      directory,
      saved,
      request_key(recorded_request),
    )
  let playback_recorder =
    matching_config.start_playback(directory) |> should.be_ok()

  // Act
  let found =
    recorder.find_recording(
      playback_recorder,
      text_request([#("Authorization", "Bearer two")], "b"),
    )
  let _ = recorder.stop(playback_recorder)
  let _ = simplifile.delete(directory)

  // Assert
  found |> should.equal(Ok(option.Some(saved)))
}

// README: Scrubbing Secrets (Transformers)

pub fn scrub_auth_and_body_removes_the_secrets_test() {
  // Arrange
  let request =
    text_request([#("Authorization", "Bearer secret"), #("X-Ok", "1")], "body")

  // Act
  let scrubbed = recording_transformer.scrub_auth_and_body(request)

  // Assert
  scrubbed |> should.equal(text_request([#("X-Ok", "1")], ""))
}

pub fn start_scrubbing_recorder_saves_the_scrubbed_request_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_recording_transformer")
  let record_recorder =
    recording_transformer.start_scrubbing_recorder(directory)
    |> should.be_ok()
  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "OK")
  let request =
    text_request(
      [#("Authorization", "Bearer secret"), #("X-Ok", "1")],
      "{\"secret\":\"value\"}",
    )

  // Act
  recorder.add_recording(
    record_recorder,
    recording.Recording(request: request, response: response),
  )
  let _ = recorder.stop(record_recorder)
  let loaded = storage.load_recordings(directory)
  let _ = simplifile.delete(directory)

  // Assert
  loaded
  |> should.equal(
    Ok([
      recording.Recording(
        request: text_request([#("X-Ok", "1")], ""),
        response: response,
      ),
    ]),
  )
}

pub fn scrub_response_removes_cookies_and_body_test() {
  // Arrange
  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [#("set-cookie", "secret_cookie=abc123"), #("X-Ok", "1")],
      body: "SECRET_BODY",
    )

  // Act
  let scrubbed =
    recording_response_transformer.scrub_response(
      text_request([], ""),
      response,
    )

  // Assert
  scrubbed
  |> should.equal(recording.BlockingResponse(
    status: 200,
    headers: [#("X-Ok", "1")],
    body: "",
  ))
}

pub fn response_scrubbing_recorder_saves_the_scrubbed_response_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_response_transformer")
  let record_recorder =
    recording_response_transformer.start_scrubbing_recorder(directory)
    |> should.be_ok()
  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [#("set-cookie", "secret_cookie=abc123")],
      body: "SECRET_BODY",
    )

  // Act
  recorder.add_recording(
    record_recorder,
    recording.Recording(request: text_request([], ""), response: response),
  )
  let _ = recorder.stop(record_recorder)
  let loaded = storage.load_recordings(directory)
  let _ = simplifile.delete(directory)

  // Assert
  loaded
  |> should.equal(
    Ok([
      recording.Recording(
        request: text_request([], ""),
        response: recording.BlockingResponse(status: 200, headers: [], body: ""),
      ),
    ]),
  )
}

// README: Ambiguous Matches (Key Collisions)

pub fn start_playback_reports_an_ambiguous_match_test() {
  // Arrange
  let directory = fresh_directory("build/snippet_ambiguous_match")
  let request = text_request([], "")
  let request_key =
    matching.request_key(method: True, url: True, headers: False, body: False)
  let _ =
    storage.save_recording_immediately(
      directory,
      recording.Recording(
        request: request,
        response: recording.BlockingResponse(
          status: 200,
          headers: [],
          body: "one",
        ),
      ),
      request_key(request),
    )
  let _ =
    storage.save_recording_immediately(
      directory,
      recording.Recording(
        request: request,
        response: recording.BlockingResponse(
          status: 200,
          headers: [],
          body: "two",
        ),
      ),
      request_key(request),
    )
  let playback_recorder =
    recording_ambiguous_match.start_playback(directory) |> should.be_ok()

  // Act
  let found = recorder.find_recording(playback_recorder, request)
  let _ = recorder.stop(playback_recorder)
  let _ = simplifile.delete(directory)

  // Assert
  found
  |> should.equal(Error(
    "Ambiguous recording match for key: "
    <> request_key(request)
    <> " (2 recordings)",
  ))
}

// README: Builder Pattern

pub fn send_post_echoes_the_body_test() {
  // Act
  let result = request_builder.send_post()

  // Assert
  result
  |> to_status_and_body
  |> should.equal(
    Ok(#(
      201,
      "{\"method\":\"POST\",\"url\":\"/post\",\"data\":\"{\\\"hello\\\":\\\"world\\\"}\"}",
    )),
  )
}

// README: Error Handling

pub fn fetch_text_with_timeout_returns_the_body_test() {
  // Act
  let result = timeout_config.fetch_text_with_timeout()

  // Assert
  result |> should.equal(Ok("Hello, World!"))
}

// Snippets that are not in the README

pub fn post_json_test() {
  post_json.post_user()
  |> should.be_ok()
}

pub fn stream_cancel_test() {
  stream_cancel.cancel_stream()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn recording_stream_yielder_test() {
  recording_stream_yielder.record_and_playback_stream_yielder()
  |> should.be_ok()
  |> should.equal(True)
}

pub fn recording_start_stream_test() {
  recording_start_stream.record_and_playback_start_stream()
  |> should.be_ok()
  |> should.equal(True)
}
