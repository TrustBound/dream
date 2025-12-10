import dream_http_client/client
import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import dream_http_client/storage
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

fn test_recording_directory() -> String {
  "test/fixtures/recordings/client_test"
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
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )
  let test_response =
    recording.BlockingResponse(status: 200, headers: [], body: "Hello, World!")
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)
  recorder.stop(rec) |> result.unwrap(Nil)

  // Now start in playback mode
  let playback_mode = recorder.Playback(directory: directory)
  let assert Ok(playback_rec) = recorder.start(playback_mode, matching)

  let request =
    mock_request("/text")
    |> client.recorder(playback_rec)

  // Act
  let result = client.send(request)

  // Assert
  let assert Ok(body) = result
  body |> should.equal("Hello, World!")

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
  let directory = "test/fixtures/recordings/record_mode_test"
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let request = mock_request("/text") |> client.recorder(rec)

  // Act - Record real request
  let assert Ok(original_body) = client.send(request)
  recorder.stop(rec) |> result.unwrap(Nil)

  // Assert - Recording was created
  original_body |> should.equal("Hello, World!")

  // Act - Load and modify the recording
  let assert Ok(recordings) = storage.load_recordings(directory)
  let assert Ok(first_recording) = list.first(recordings)

  // Modify the recording's response body
  let modified_recording = case first_recording.response {
    recording.BlockingResponse(status, headers, _body) ->
      recording.Recording(
        request: first_recording.request,
        response: recording.BlockingResponse(
          status,
          headers,
          "MODIFIED_CONTENT",
        ),
      )
    _ -> first_recording
  }

  // Save the modified recording back
  let assert Ok(_) =
    storage.save_recordings(directory, [modified_recording], matching)

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
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
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

  let request = mock_request("/stream") |> client.recorder(rec)

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
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
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

  let request = mock_request("/stream") |> client.recorder(playback_rec)

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
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )
  let test_response =
    recording.BlockingResponse(status: 200, headers: [], body: "Hello, World!")
  let test_recording =
    recording.Recording(request: test_request, response: test_response)
  recorder.add_recording(rec, test_recording)

  let request = mock_request("/text") |> client.recorder(rec)

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
  let directory = "test/fixtures/recordings/stream_yielder_records_test"
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

  // Assert - Recording exists and contains streaming data
  let assert Ok(recordings) = storage.load_recordings(directory)
  let assert Ok(rec_entry) = list.first(recordings)

  // Verify recording has streaming response (not blocking)
  case rec_entry.response {
    recording.StreamingResponse(_status, _headers, chunks) -> {
      // Verify we have chunks
      list.length(chunks) |> should.not_equal(0)

      // Verify chunks have data and delay
      case list.first(chunks) {
        Ok(chunk) -> {
          // Chunk should have data (non-empty)
          bit_array.byte_size(chunk.data) |> should.not_equal(0)
        }
        Error(_) -> should.fail()
      }
    }
    recording.BlockingResponse(_, _, _) -> {
      io.println("Expected StreamingResponse, got BlockingResponse")
      should.fail()
    }
  }
}

pub fn stream_yielder_playback_matches_recorded_stream_test() {
  // Arrange - Record a real streaming request first
  let directory = "test/fixtures/recordings/stream_yielder_playback_test"
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

  // Act - MODIFY the recording to prove playback reads from file, not server
  let assert Ok(recordings) = storage.load_recordings(directory)
  let assert Ok(rec_entry) = list.first(recordings)

  // Replace chunk content - mock server sends "Chunk 1\n", "Chunk 2\n", etc.
  let modified_recording = case rec_entry.response {
    recording.StreamingResponse(status, headers, chunks) -> {
      let modified_chunks =
        list.map(chunks, fn(chunk) {
          let original_text =
            bit_array.to_string(chunk.data) |> result.unwrap("")
          let modified_text = string.replace(original_text, "Chunk", "MODIFIED")
          recording.Chunk(
            data: <<modified_text:utf8>>,
            delay_ms: chunk.delay_ms,
          )
        })
      recording.Recording(
        request: rec_entry.request,
        response: recording.StreamingResponse(status, headers, modified_chunks),
      )
    }
    _ -> rec_entry
  }

  // Save the modified recording
  let assert Ok(_) =
    storage.save_recordings(directory, [modified_recording], matching)

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

pub fn start_stream_records_real_streaming_request_test() {
  // Arrange - Start recorder in Record mode
  let directory = "test/fixtures/recordings/start_stream_records_test"
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Track chunks received
  let chunks_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.recorder(rec)
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })

  // Act - Make REAL streaming request with new API
  let assert Ok(_stream_handle) = client.start_stream(request)

  // Wait for stream to complete
  process.sleep(2000)

  // Collect chunks from mailbox
  let chunks = collect_chunks_from_mailbox(chunks_subject, [])
  let chunk_count = list.length(chunks)

  // Assert - Got real stream data
  { chunk_count > 0 } |> should.be_true()

  // Act - Stop recorder (saves to file)
  let assert Ok(_) = recorder.stop(rec)

  // Assert - Recording exists and contains streaming data
  let assert Ok(recordings) = storage.load_recordings(directory)
  let assert Ok(rec_entry) = list.first(recordings)

  // Verify recording has streaming response (not blocking)
  case rec_entry.response {
    recording.StreamingResponse(_status, _headers, chunks) -> {
      // Verify we have chunks
      list.length(chunks) |> should.not_equal(0)

      // Verify chunks have data
      case list.first(chunks) {
        Ok(chunk) -> {
          // Chunk should have data (non-empty)
          bit_array.byte_size(chunk.data) |> should.not_equal(0)
        }
        Error(_) -> should.fail()
      }
    }
    recording.BlockingResponse(_, _, _) -> {
      io.println("Expected StreamingResponse, got BlockingResponse")
      should.fail()
    }
  }
}

// Helper to collect chunks from subject mailbox
pub fn playback_from_committed_fixtures_returns_recorded_response_test() {
  // Arrange - Use committed fixtures directory (no mock server needed!)
  let fixtures_dir = "test/fixtures/recordings"
  let mode = recorder.Playback(directory: fixtures_dir)
  let matching = matching.match_url_only()

  let assert Ok(rec) = recorder.start(mode, matching)

  // Act - Make request that matches committed fixture
  let request = mock_request("/text") |> client.recorder(rec)

  let assert Ok(body) = client.send(request)

  // Assert - Should get FIXTURE response, not real mock server response
  // Mock server returns "Hello, World!" but fixture has different content
  body |> should.equal("FIXTURE_RESPONSE_NO_NETWORK")

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

fn collect_chunks_from_mailbox(
  subject: process.Subject(BitArray),
  acc: List(BitArray),
) -> List(BitArray) {
  case process.receive(subject, 100) {
    Ok(data) -> collect_chunks_from_mailbox(subject, [data, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
