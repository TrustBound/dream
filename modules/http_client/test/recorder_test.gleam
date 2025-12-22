import dream_http_client/recorder.{directory, mode, start}
import dream_http_client/recording
import dream_http_client/storage
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn temp_directory(label: String) -> String {
  "/tmp/dream_http_client_recorder_"
  <> label
  <> "_"
  <> string.inspect(get_timestamp())
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

pub fn start_with_record_mode_returns_recorder_test() {
  let recordings_directory_path = temp_directory("start_record")

  let start_result =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  case start_result {
    Ok(rec) -> {
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
  let recordings_directory_path = temp_directory("start_playback")

  let start_result =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  case start_result {
    Ok(rec) -> {
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
  let start_result =
    recorder.new()
    |> mode("passthrough")
    |> start()

  case start_result {
    Ok(rec) -> {
      recorder.stop(rec) |> result.unwrap(Nil)
      Nil
    }
    Error(reason) -> {
      io.println("Test failed: " <> reason)
      should.fail()
    }
  }
}

pub fn start_validates_mode_and_directory_test() {
  // Unknown mode
  let unknown = recorder.new() |> mode("foo") |> start()
  unknown |> should.be_error()

  // Strict parsing
  let strict = recorder.new() |> mode("RECORD") |> start()
  strict |> should.be_error()

  // Record/playback require a directory
  let record_no_dir = recorder.new() |> mode("record") |> start()
  record_no_dir |> should.be_error()

  let playback_no_dir = recorder.new() |> mode("playback") |> start()
  playback_no_dir |> should.be_error()

  // Passthrough does not
  let passthrough_ok = recorder.new() |> mode("passthrough") |> start()
  passthrough_ok |> should.be_ok()
}

pub fn is_record_mode_with_record_mode_returns_true_test() {
  let recordings_directory_path = temp_directory("is_record_true")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  recorder.is_record_mode(rec) |> should.equal(True)
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn is_record_mode_with_playback_mode_returns_false_test() {
  let recordings_directory_path = temp_directory("is_record_false_playback")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  recorder.is_record_mode(rec) |> should.equal(False)
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn is_record_mode_with_passthrough_mode_returns_false_test() {
  let assert Ok(rec) =
    recorder.new()
    |> mode("passthrough")
    |> start()

  recorder.is_record_mode(rec) |> should.equal(False)
  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn add_recording_in_record_mode_stores_recording_test() {
  let recordings_directory_path = temp_directory("store")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  let test_recording = create_test_recording()
  recorder.add_recording(rec, test_recording)

  let recordings = recorder.get_recordings(rec)
  list.length(recordings) |> should.equal(1)

  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn find_recording_in_playback_mode_with_no_file_returns_none_test() {
  let recordings_directory_path = temp_directory("nonexistent")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  let test_request = create_test_recording().request

  let found = recorder.find_recording(rec, test_request)
  found |> should.equal(Ok(option.None))

  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn find_recording_with_matching_request_returns_recording_test() {
  let recordings_directory_path = temp_directory("find")
  let test_recording = create_test_recording()

  // Record first
  let assert Ok(recorder_rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  recorder.add_recording(recorder_rec, test_recording)

  // Wait for actor to process message and file write to complete
  process.sleep(100)
  recorder.stop(recorder_rec) |> result.unwrap(Nil)

  // Playback
  let assert Ok(playback) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  let found = recorder.find_recording(playback, test_recording.request)

  case found {
    Ok(option.Some(r)) -> {
      r.request.host |> should.equal("localhost")
      r.request.path |> should.equal("/text")
    }
    Ok(option.None) -> should.fail()
    Error(reason) -> {
      io.println("Unexpected error: " <> reason)
      should.fail()
    }
  }

  recorder.stop(playback) |> result.unwrap(Nil)
}

pub fn find_recording_with_non_matching_request_returns_none_test() {
  let recordings_directory_path = temp_directory("find_non_match")
  let test_recording = create_test_recording()

  let assert Ok(recorder_rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  recorder.add_recording(recorder_rec, test_recording)
  process.sleep(100)
  recorder.stop(recorder_rec) |> result.unwrap(Nil)

  let assert Ok(playback) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  let different_request =
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

  recorder.find_recording(playback, different_request)
  |> should.equal(Ok(option.None))

  recorder.stop(playback) |> result.unwrap(Nil)
}

pub fn get_recordings_with_multiple_recordings_returns_all_test() {
  let recordings_directory_path = temp_directory("multi")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  let recording1 = create_test_recording()
  let recording2 =
    recording.Recording(
      request: recording.RecordedRequest(
        method: http.Get,
        scheme: http.Http,
        host: "localhost",
        port: option.Some(9876),
        path: "/stream",
        query: option.None,
        headers: [],
        body: "",
      ),
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "Stream response",
      ),
    )

  recorder.add_recording(rec, recording1)
  recorder.add_recording(rec, recording2)

  let recordings = recorder.get_recordings(rec)
  list.length(recordings) |> should.equal(2)

  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn add_recording_in_record_mode_saves_immediately_test() {
  let recordings_directory_path = temp_directory("save_immediately")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  let test_recording = create_test_recording()
  recorder.add_recording(rec, test_recording)

  // Wait for actor to process message and file write to complete
  process.sleep(100)

  let assert Ok(recordings) = storage.load_recordings(recordings_directory_path)

  let found =
    list.any(recordings, fn(r) {
      r.request.host == "localhost" && r.request.path == "/text"
    })
  found |> should.be_true()

  recorder.stop(rec) |> result.unwrap(Nil)
}

pub fn stop_with_record_mode_returns_ok_test() {
  let recordings_directory_path = temp_directory("stop_record")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  recorder.stop(rec) |> should.be_ok()
}

pub fn stop_with_playback_mode_returns_ok_test() {
  let recordings_directory_path = temp_directory("stop_playback")
  let assert Ok(rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  recorder.stop(rec) |> should.be_ok()
}

pub fn stop_with_passthrough_mode_returns_ok_test() {
  let assert Ok(rec) =
    recorder.new()
    |> mode("passthrough")
    |> start()

  recorder.stop(rec) |> should.be_ok()
}

pub fn playback_errors_on_ambiguous_key_collision_test() {
  let recordings_directory_path = temp_directory("ambiguous")

  let base = create_test_recording()
  let rec1 = base
  let rec2 =
    recording.Recording(
      request: base.request,
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "Different",
      ),
    )

  let assert Ok(recorder_rec) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start()

  recorder.add_recording(recorder_rec, rec1)
  recorder.add_recording(recorder_rec, rec2)
  process.sleep(100)
  recorder.stop(recorder_rec) |> result.unwrap(Nil)

  let assert Ok(playback) =
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start()

  recorder.find_recording(playback, base.request) |> should.be_error()

  recorder.stop(playback) |> result.unwrap(Nil)
}
