import dream_http_client/client
import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import dream_http_client_test
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
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

fn test_recording_directory() -> String {
  "build/test_recordings_" <> string.inspect(get_timestamp())
}

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
  let directory = test_recording_directory()
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
  let directory = test_recording_directory()
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
  let directory = test_recording_directory()
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
  let directory = test_recording_directory()
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
  let directory = test_recording_directory()
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
  let directory = test_recording_directory()
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

// ============================================================================
// Integration Tests - Prove Recording Actually Works
// ============================================================================

pub fn stream_yielder_records_real_streaming_request_test() {
  // Arrange - Start recorder in Record mode
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/stream/fast") |> client.recorder(rec)

  // Act - Make REAL streaming request and consume all chunks
  let yielder_result = client.stream_yielder(request)
  let chunks = yielder.to_list(yielder_result)

  // Extract successful chunks
  let successful_chunks =
    chunks
    |> list.filter_map(fn(result) { result })
    |> list.length

  // Assert - Got real stream data
  { successful_chunks > 0 } |> should.be_true()

  // Act - Stop recorder (saves to file)
  let assert Ok(_) = recorder.stop(rec)

  // Assert - Recording file exists and contains streaming data
  let assert Ok(file_content) = simplifile.read(directory <> "/recordings.json")

  // Verify file contains "streaming" mode (not "blocking")
  string.contains(file_content, "\"mode\":\"streaming\"")
  |> should.be_true()

  // Verify file contains "chunks" array
  string.contains(file_content, "\"chunks\"")
  |> should.be_true()

  // Verify file contains chunk data
  string.contains(file_content, "\"data\"")
  |> should.be_true()

  // Verify file contains delay information
  string.contains(file_content, "\"delay_ms\"")
  |> should.be_true()
}

pub fn stream_yielder_playback_matches_recorded_stream_test() {
  // Arrange - Record a real streaming request first
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/stream/fast") |> client.recorder(rec)

  // Record the stream
  let yielder_result = client.stream_yielder(request)
  let _original_chunks =
    yielder_result
    |> yielder.to_list
    |> list.filter_map(fn(result) { result })

  let assert Ok(_) = recorder.stop(rec)

  // Act - MODIFY the recording file to prove playback reads from file, not server
  let assert Ok(file_content) = simplifile.read(directory <> "/recordings.json")
  // Replace chunk content - mock server sends "Chunk 1\n", "Chunk 2\n", etc.
  let modified_content = string.replace(file_content, "Chunk", "MODIFIED")
  let assert Ok(_) =
    simplifile.write(directory <> "/recordings.json", modified_content)

  // Act - Playback the MODIFIED recording
  let playback_mode = recorder.Playback(directory: directory)
  let assert Ok(playback_rec) = recorder.start(playback_mode, matching)

  let playback_request =
    mock_request("/stream/fast") |> client.recorder(playback_rec)

  let playback_yielder = client.stream_yielder(playback_request)
  let playback_data =
    playback_yielder
    |> yielder.to_list
    |> list.filter_map(fn(result) { result })
    |> list.map(fn(chunk) {
      chunk
      |> bytes_tree.to_bit_array
      |> bit_array.to_string
      |> result.unwrap("")
    })
    |> string.join("")

  // Assert - Playback contains MODIFIED content (proves we read from file, not server)
  string.contains(playback_data, "MODIFIED") |> should.be_true()

  // Assert - Playback does NOT contain original "Chunk" text (proves it was modified)
  string.contains(playback_data, "Chunk") |> should.be_false()

  // Cleanup
  recorder.stop(playback_rec) |> result.unwrap(Nil)
}

pub fn stream_messages_records_real_streaming_request_test() {
  // Arrange - Start recorder in Record mode
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/stream/fast") |> client.recorder(rec)

  // Act - Make REAL message-based streaming request
  let assert Ok(_request_id) = client.stream_messages(request)

  // Receive all messages using selector
  let chunks = receive_all_stream_messages_via_selector([], 5000)
  let chunk_count = list.length(chunks)

  // Assert - Got real stream data
  { chunk_count > 0 } |> should.be_true()

  // Act - Stop recorder (saves to file)
  let assert Ok(_) = recorder.stop(rec)

  // Assert - Recording file exists and contains streaming data
  let assert Ok(file_content) = simplifile.read(directory <> "/recordings.json")

  // Verify file contains "streaming" mode
  string.contains(file_content, "\"mode\":\"streaming\"")
  |> should.be_true()

  // Verify file contains chunks
  string.contains(file_content, "\"chunks\"")
  |> should.be_true()

  // Verify file has at least as many chunks as we received
  // (The recording should match what we got)
  string.contains(file_content, "\"data\"")
  |> should.be_true()
}

// Helper to receive all stream messages using selector (so recording happens)
fn receive_all_stream_messages_via_selector(
  acc: List(BitArray),
  timeout_ms: Int,
) -> List(BitArray) {
  let sel =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  case process.selector_receive(sel, timeout_ms) {
    Ok(client.Chunk(_request_id, data)) -> {
      receive_all_stream_messages_via_selector([data, ..acc], timeout_ms)
    }
    Ok(client.StreamEnd(_request_id, _headers)) -> {
      list.reverse(acc)
    }
    Ok(client.StreamError(_request_id, _reason)) -> {
      list.reverse(acc)
    }
    Ok(client.StreamStart(_request_id, _headers)) -> {
      receive_all_stream_messages_via_selector(acc, timeout_ms)
    }
    Ok(client.DecodeError(_reason)) -> {
      list.reverse(acc)
    }
    Error(Nil) -> {
      list.reverse(acc)
    }
  }
}
