import dream_http_client/matching
import dream_http_client/recorder
import dream_http_client/recording
import gleam/http
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn test_recording_directory() -> String {
  "build/test_recordings_" <> string.inspect(get_timestamp())
}

fn create_test_recording() -> recording.Recording {
  let request =
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
  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [],
      body: "{\"users\": []}",
    )
  recording.Recording(request: request, response: response)
}

pub fn start_with_record_mode_returns_recorder_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()

  // Act
  let result = recorder.start(mode, matching)

  // Assert
  case result {
    Ok(rec) -> {
      // Cleanup
      recorder.stop(rec) |> result.unwrap(Nil)
      Nil
    }
    Error(reason) -> {
      io.println("Test failed: " <> reason)
      should.fail()
    }
  }
}

pub fn start_with_playback_mode_returns_recorder_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Playback(directory: directory)
  let matching = matching.match_url_only()

  // Act
  let result = recorder.start(mode, matching)

  // Assert
  case result {
    Ok(rec) -> {
      // Cleanup
      recorder.stop(rec) |> result.unwrap(Nil)
      Nil
    }
    Error(reason) -> {
      io.println("Test failed: " <> reason)
      should.fail()
    }
  }
}

pub fn start_with_passthrough_mode_returns_recorder_test() {
  // Arrange
  let mode = recorder.Passthrough
  let matching = matching.match_url_only()

  // Act
  let result = recorder.start(mode, matching)

  // Assert
  case result {
    Ok(rec) -> {
      // Cleanup
      recorder.stop(rec) |> result.unwrap(Nil)
      Nil
    }
    Error(reason) -> {
      io.println("Test failed: " <> reason)
      should.fail()
    }
  }
}

pub fn is_record_mode_with_record_mode_returns_true_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let result = recorder.is_record_mode(rec)

  // Assert
  result |> should.equal(True)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn is_record_mode_with_playback_mode_returns_false_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Playback(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let result = recorder.is_record_mode(rec)

  // Assert
  result |> should.equal(False)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn is_record_mode_with_passthrough_mode_returns_false_test() {
  // Arrange
  let mode = recorder.Passthrough
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let result = recorder.is_record_mode(rec)

  // Assert
  result |> should.equal(False)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn add_recording_in_record_mode_stores_recording_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)
  let test_recording = create_test_recording()

  // Act
  recorder.add_recording(rec, test_recording)
  let recordings = recorder.get_recordings(rec)

  // Assert
  list.length(recordings) |> should.equal(1)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn find_recording_with_matching_request_returns_recording_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)
  let test_recording = create_test_recording()
  recorder.add_recording(rec, test_recording)

  // Act
  let result = recorder.find_recording(rec, test_recording.request)

  // Assert
  case result {
    option.Some(found) -> {
      found.request.host |> should.equal("api.example.com")
      found.request.path |> should.equal("/users")
    }
    option.None -> should.fail()
  }

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn find_recording_with_non_matching_request_returns_none_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)
  let test_recording = create_test_recording()
  recorder.add_recording(rec, test_recording)

  let different_request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/posts",
      query: option.None,
      headers: [],
      body: "",
    )

  // Act
  let result = recorder.find_recording(rec, different_request)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn get_recordings_with_multiple_recordings_returns_all_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  let recording1 = create_test_recording()
  let recording2 =
    recording.Recording(
      request: recording.RecordedRequest(
        method: http.Get,
        scheme: http.Https,
        host: "api.example.com",
        port: option.None,
        path: "/posts",
        query: option.None,
        headers: [],
        body: "",
      ),
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "{\"posts\": []}",
      ),
    )

  recorder.add_recording(rec, recording1)
  recorder.add_recording(rec, recording2)

  // Act
  let recordings = recorder.get_recordings(rec)

  // Assert
  list.length(recordings) |> should.equal(2)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn stop_with_record_mode_saves_recordings_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)
  let test_recording = create_test_recording()
  recorder.add_recording(rec, test_recording)

  // Act
  let result = recorder.stop(rec)

  // Assert
  result |> should.be_ok()
}

pub fn stop_with_playback_mode_does_not_save_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Playback(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let result = recorder.stop(rec)

  // Assert
  result |> should.be_ok()
}

pub fn stop_with_passthrough_mode_does_not_save_test() {
  // Arrange
  let mode = recorder.Passthrough
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let result = recorder.stop(rec)

  // Assert
  result |> should.be_ok()
}

pub fn find_recording_in_playback_mode_with_no_file_returns_none_test() {
  // Arrange
  let directory =
    "/tmp/test_mocks_nonexistent_" <> string.inspect(get_timestamp())
  let mode = recorder.Playback(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

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

  // Act
  let result = recorder.find_recording(rec, test_request)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn add_recording_then_find_recording_returns_same_recording_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)
  let test_recording = create_test_recording()

  // Act
  recorder.add_recording(rec, test_recording)
  let found = recorder.find_recording(rec, test_recording.request)

  // Assert
  case found {
    option.Some(found_recording) -> {
      found_recording.request.host |> should.equal(test_recording.request.host)
      found_recording.request.path |> should.equal(test_recording.request.path)
    }
    option.None -> should.fail()
  }

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn get_recordings_with_no_recordings_returns_empty_list_test() {
  // Arrange
  let directory = test_recording_directory()
  let mode = recorder.Record(directory: directory)
  let matching = matching.match_url_only()
  let assert Ok(rec) = recorder.start(mode, matching)

  // Act
  let recordings = recorder.get_recordings(rec)

  // Assert
  list.length(recordings) |> should.equal(0)

  // Cleanup
  recorder.stop(rec) |> result.unwrap(Nil)
}
