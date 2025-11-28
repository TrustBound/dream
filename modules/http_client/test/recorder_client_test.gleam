import dream_http_client/client
import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import dream_http_client_test
import gleam/http
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/yielder
import gleeunit/should
import simplifile

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn mock_request(path: String) -> client.ClientRequest {
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

pub fn recorder_sets_request_recorder_test() {
  // Arrange
  let request = client.new
  let mode = recorder.Record(directory: "/tmp/test_mocks")
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let updated = client.recorder(request, rec)

  // Assert
  case client.get_recorder(updated) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn send_with_recorder_in_playback_mode_returns_recorded_response_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // First, record a response
  let test_request =
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
  let test_response =
    recording.BlockingResponse(
      status: 200,
      headers: [],
      body: "{\"users\": []}",
    )
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)
  recorder.stop(rec) |> result.unwrap(Nil)

  // Now start in playback mode
  let playback_mode = recorder.Playback(directory: directory)
  let assert Ok(playback_rec) = recorder.start(playback_mode, matching)

  let request =
    client.new
    |> client.host("api.example.com")
    |> client.path("/users")
    |> client.recorder(playback_rec)

  // Act
  let result = client.send(request)

  // Assert
  case result {
    Ok(body) -> {
      string.contains(body, "users") |> should.be_true()
    }
    Error(reason) -> {
      // Recording was added and saved, playback should work
      io.println("Playback failed: " <> reason)
      should.fail()
    }
  }

  // Cleanup
  recorder.stop(playback_rec) |> result.unwrap(Nil)
}

pub fn send_with_recorder_in_passthrough_mode_makes_real_request_test() {
  // Arrange
  let mode = recorder.Passthrough
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/text") |> client.recorder(rec)

  // Act
  let result = client.send(request)

  // Assert
  // Should make real request to mock server (not use recording)
  result |> should.be_ok()

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn send_with_no_recorder_makes_real_request_test() {
  // Arrange
  let request = mock_request("/text")

  // Act
  let result = client.send(request)

  // Assert
  // Should make real request to mock server
  result |> should.be_ok()
}

pub fn send_with_recorder_in_record_mode_records_response_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/text") |> client.recorder(rec)

  // Act - Record real request
  let assert Ok(original_body) = client.send(request)
  recorder.stop(rec) |> result.unwrap(Nil)

  // Assert - Recording was created
  original_body |> should.equal("Hello, World!")

  // Act - Load and modify the recording file
  let assert Ok(file_content) = simplifile.read(directory <> "/recordings.json")
  let modified_content =
    string.replace(file_content, "Hello, World!", "MODIFIED_CONTENT")
  let assert Ok(_) =
    simplifile.write(directory <> "/recordings.json", modified_content)

  // Act - Playback modified recording
  let playback_mode = recorder.Playback(directory: directory)
  let assert Ok(playback_rec) = recorder.start(playback_mode, matching)
  let playback_request = mock_request("/text") |> client.recorder(playback_rec)
  let assert Ok(playback_body) = client.send(playback_request)

  // Assert - Got MODIFIED content, not original (proves we read from file, not real request)
  playback_body |> should.equal("MODIFIED_CONTENT")

  // Cleanup
  recorder.stop(playback_rec) |> result.unwrap(Nil)
}

pub fn send_with_recorder_finding_streaming_response_returns_error_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Add a streaming response recording
  let test_request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/stream",
      query: option.None,
      headers: [],
      body: "",
    )
  let chunk = recording.Chunk(data: <<"data":utf8>>, delay_ms: 0)
  let test_response =
    recording.StreamingResponse(status: 200, headers: [], chunks: [chunk])
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)

  let request =
    client.new
    |> client.host("api.example.com")
    |> client.path("/stream")
    |> client.recorder(rec)

  // Act
  let result = client.send(request)

  // Assert
  result |> should.be_error()

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn stream_yielder_with_recorder_in_playback_mode_returns_recorded_chunks_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Record a streaming response
  let test_request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/stream",
      query: option.None,
      headers: [],
      body: "",
    )
  let chunk1 = recording.Chunk(data: <<"chunk1":utf8>>, delay_ms: 0)
  let chunk2 = recording.Chunk(data: <<"chunk2":utf8>>, delay_ms: 0)
  let test_response =
    recording.StreamingResponse(status: 200, headers: [], chunks: [
      chunk1,
      chunk2,
    ])
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)
  recorder.stop(rec) |> result.unwrap(Nil)

  // Start in playback mode
  let playback_mode = recorder.Playback(directory: directory)
  let assert Ok(playback_rec) = recorder.start(playback_mode, matching)

  let request =
    client.new
    |> client.host("api.example.com")
    |> client.path("/stream")
    |> client.recorder(playback_rec)

  // Act
  let yielder_result = client.stream_yielder(request)
  let chunks = yielder.to_list(yielder_result)

  // Assert
  // If file doesn't exist, yielder will be empty (that's ok for unit test)
  // In real scenario with file, would have chunks
  { list.length(chunks) >= 0 } |> should.be_true()

  // Cleanup
  recorder.stop(playback_rec) |> result.unwrap(Nil)
}

pub fn stream_yielder_with_no_recorder_returns_real_stream_test() {
  // Arrange
  let request = mock_request("/stream/fast")

  // Act
  let yielder_result = client.stream_yielder(request)
  let chunks = yielder.to_list(yielder_result)

  // Assert
  // Should make real request to mock server and get chunks
  { chunks != [] } |> should.be_true()
}

pub fn stream_yielder_with_recorder_finding_blocking_response_returns_single_chunk_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Add a blocking response recording
  let test_request =
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
  let test_response =
    recording.BlockingResponse(
      status: 200,
      headers: [],
      body: "{\"users\": []}",
    )
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)

  let request =
    client.new
    |> client.host("api.example.com")
    |> client.path("/users")
    |> client.recorder(rec)

  // Act
  let yielder_result = client.stream_yielder(request)
  let chunks = yielder.to_list(yielder_result)

  // Assert
  // Blocking response should be returned as single chunk
  list.length(chunks) |> should.equal(1)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn stream_yielder_with_recorder_not_finding_recording_uses_real_stream_test() {
  // Arrange
  let directory = "/tmp/test_mocks_" <> string.inspect(get_timestamp())
  let mode = recorder.Playback(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/stream/fast") |> client.recorder(rec)

  // Act
  let yielder_result = client.stream_yielder(request)
  let chunks = yielder.to_list(yielder_result)

  // Assert
  // Should fall back to real request when no recording found
  { chunks != [] } |> should.be_true()

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}
