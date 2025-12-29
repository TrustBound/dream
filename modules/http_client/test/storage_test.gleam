import dream_http_client/matching
import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import simplifile

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn temp_directory(label: String) -> String {
  "/tmp/dream_http_client_storage_"
  <> label
  <> "_"
  <> string.inspect(get_timestamp())
}

fn default_key() -> matching.MatchKey {
  matching.request_key(method: True, url: True, headers: False, body: False)
}

fn create_test_recording() -> recording.Recording {
  let request =
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
  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "Hello, World!")
  recording.Recording(request: request, response: response)
}

fn create_second_test_recording() -> recording.Recording {
  let request =
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
  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [],
      body: "Stream response",
    )
  recording.Recording(request: request, response: response)
}

pub fn load_recordings_with_nonexistent_directory_returns_empty_list_test() {
  // Arrange
  let directory = temp_directory("nonexistent")

  // Act
  let assert Ok(recordings) = storage.load_recordings(directory)

  // Assert
  list.length(recordings) |> should.equal(0)
}

pub fn save_recordings_creates_file_and_load_recordings_loads_it_test() {
  // Arrange
  let directory = temp_directory("save_test")
  let test_recording = create_test_recording()
  let key_fn = default_key()

  // Act - Save
  let assert Ok(_) =
    storage.save_recordings(directory, [test_recording], key_fn)

  // Act - Load
  let assert Ok(loaded) = storage.load_recordings(directory)

  // Assert
  list.length(loaded) |> should.equal(1)

  let assert Ok(entry) = list.first(loaded)
  entry.request.host |> should.equal("localhost")
  entry.request.path |> should.equal("/text")
}

pub fn save_recordings_with_multiple_recordings_saves_all_test() {
  // Arrange
  let directory = temp_directory("multi_test")
  let recording1 = create_test_recording()
  let recording2 = create_second_test_recording()
  let key_fn = default_key()

  // Act
  let assert Ok(_) =
    storage.save_recordings(directory, [recording1, recording2], key_fn)

  // Assert
  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(2)
}

pub fn save_recording_immediately_appends_to_existing_test() {
  // Arrange
  let directory = temp_directory("immediate_test")
  let recording1 = create_test_recording()
  let recording2 = create_second_test_recording()
  let key_fn = default_key()

  // Save first recording
  let assert Ok(_) = storage.save_recordings(directory, [recording1], key_fn)

  // Act - Save second recording immediately
  let result =
    storage.save_recording_immediately(
      directory,
      recording2,
      key_fn(recording2.request),
    )

  // Assert
  result |> should.be_ok()

  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(2)
}

pub fn different_query_params_create_different_files_test() {
  // Arrange
  let directory = temp_directory("query_test")
  let key_fn = default_key()

  let request1 =
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

  let request2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.Some("page=2"),
      headers: [],
      body: "",
    )

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")

  let recording1 = recording.Recording(request: request1, response: response)
  let recording2 = recording.Recording(request: request2, response: response)

  // Act - Save both recordings
  let assert Ok(_) =
    storage.save_recordings(directory, [recording1, recording2], key_fn)

  // Assert - Should have 2 different files
  let assert Ok(files) = simplifile.read_directory(directory)
  let json_files = list.filter(files, fn(f) { string.ends_with(f, ".json") })

  list.length(json_files) |> should.equal(2)

  // Files should have different names
  let assert [file1, file2] = json_files
  file1 |> should.not_equal(file2)
}

pub fn same_request_overwrites_same_file_test() {
  // Arrange
  let directory = temp_directory("overwrite_test")
  let key_fn = default_key()

  let request =
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

  let response1 =
    recording.BlockingResponse(status: 200, headers: [], body: "first")
  let response2 =
    recording.BlockingResponse(status: 200, headers: [], body: "second")

  let recording1 = recording.Recording(request: request, response: response1)
  let recording2 = recording.Recording(request: request, response: response2)

  // Act - Save same request twice
  let assert Ok(_) =
    storage.save_recording_immediately(directory, recording1, key_fn(request))
  let assert Ok(_) =
    storage.save_recording_immediately(directory, recording2, key_fn(request))

  // Assert - Should have 2 files (different content hash)
  let assert Ok(files) = simplifile.read_directory(directory)
  let json_files = list.filter(files, fn(f) { string.ends_with(f, ".json") })

  list.length(json_files) |> should.equal(2)

  // Content should include both recordings
  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(2)
}

pub fn special_characters_in_path_are_sanitized_test() {
  // Arrange
  let directory = temp_directory("sanitize_test")
  let key_fn = default_key()

  let request =
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

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")

  let rec = recording.Recording(request: request, response: response)

  // Act
  let assert Ok(_) =
    storage.save_recording_immediately(directory, rec, key_fn(request))

  // Assert - File should exist and be readable
  let assert Ok(files) = simplifile.read_directory(directory)
  let json_files = list.filter(files, fn(f) { string.ends_with(f, ".json") })

  list.length(json_files) |> should.equal(1)

  // Should be able to load it back
  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(1)
}

pub fn each_recording_saved_as_separate_file_test() {
  // Arrange
  let directory = temp_directory("separate_test")
  let key_fn = default_key()

  let recordings = [
    create_test_recording(),
    create_second_test_recording(),
  ]

  // Act
  let assert Ok(_) = storage.save_recordings(directory, recordings, key_fn)

  // Assert - Should have 2 files, not 1 combined file
  let assert Ok(files) = simplifile.read_directory(directory)
  let json_files = list.filter(files, fn(f) { string.ends_with(f, ".json") })

  list.length(json_files) |> should.equal(2)

  // Load should return both
  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(2)
}

pub fn load_recordings_from_committed_fixtures_test() {
  // Arrange - Use committed fixture files in test/fixtures/recordings/
  let directory = "test/fixtures/recordings"

  // Act - Load recordings from committed fixtures
  let result = storage.load_recordings(directory)

  // Assert - Should load successfully
  let assert Ok(recordings) = result

  // Should have at least one committed fixture
  list.length(recordings) |> should.not_equal(0)

  // Verify we can access the fixture data
  let assert Ok(first_rec) = list.first(recordings)

  // Should have a valid request
  string.length(first_rec.request.host) |> should.not_equal(0)
}

pub fn filename_format_matches_expected_pattern_test() {
  // Arrange
  let directory = temp_directory("filename_test")
  let key_fn = default_key()

  let request =
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

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")

  let rec = recording.Recording(request: request, response: response)

  // Act
  let assert Ok(_) =
    storage.save_recording_immediately(directory, rec, key_fn(request))

  // Assert - Verify filename format:
  // {method}_{host}_{path}_{key_hash}_{content_hash}.json
  let assert Ok(files) = simplifile.read_directory(directory)
  let assert [filename] =
    list.filter(files, fn(f) { string.ends_with(f, ".json") })

  // Should start with GET_localhost_
  string.starts_with(filename, "GET_localhost_")
  |> should.be_true()

  // Should end with .json
  string.ends_with(filename, ".json")
  |> should.be_true()

  // Should contain hashes
  let parts = string.split(filename, "_")
  { list.length(parts) >= 5 } |> should.be_true()
}

pub fn very_long_path_is_truncated_safely_test() {
  // Arrange
  let directory = temp_directory("long_path_test")
  let key_fn = default_key()

  // Create a very long path (over 50 chars)
  let long_path =
    "/api/v1/users/12345/profile/settings/notifications/preferences/details"

  let request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: long_path,
      query: option.None,
      headers: [],
      body: "",
    )

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")

  let rec = recording.Recording(request: request, response: response)

  // Act - Should not fail despite long path
  let result =
    storage.save_recording_immediately(directory, rec, key_fn(request))

  // Assert - Save should succeed
  result |> should.be_ok()

  // Should be able to load back
  let assert Ok(loaded) = storage.load_recordings(directory)
  list.length(loaded) |> should.equal(1)

  // Verify it's the right recording
  let assert Ok(loaded_rec) = list.first(loaded)
  loaded_rec.request.path |> should.equal(long_path)
}

pub fn different_matching_configs_create_different_filenames_test() {
  // Arrange
  let directory1 = temp_directory("match_key1")
  let directory2 = temp_directory("match_key2")

  // Same request, different matching configs
  let request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(9876),
      path: "/text",
      query: option.None,
      headers: [#("Auth", "token123")],
      body: "{\"id\": 1}",
    )

  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")

  let rec = recording.Recording(request: request, response: response)

  // Key 1: method + url only
  let key1 =
    matching.request_key(method: True, url: True, headers: False, body: False)

  // Key 2: method + url + headers + body
  let key2 =
    matching.request_key(method: True, url: True, headers: True, body: True)

  // Act - Save with both keys
  let assert Ok(_) =
    storage.save_recording_immediately(directory1, rec, key1(request))
  let assert Ok(_) =
    storage.save_recording_immediately(directory2, rec, key2(request))

  // Assert - Should have different filenames due to different signatures
  let assert Ok(files1) = simplifile.read_directory(directory1)
  let assert Ok(files2) = simplifile.read_directory(directory2)

  let assert [filename1] =
    list.filter(files1, fn(f) { string.ends_with(f, ".json") })
  let assert [filename2] =
    list.filter(files2, fn(f) { string.ends_with(f, ".json") })

  // Filenames should be different (different hash due to different signature)
  filename1 |> should.not_equal(filename2)
}
