//// Recorder process and state management
////
//// Manages HTTP request/response recordings using a process to store state.
//// Supports recording, playback, and passthrough modes.

import dream_http_client/matching
import dream_http_client/recording
import dream_http_client/storage
import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/actor.{type Next}
import gleam/result
import gleam/string

/// Opaque recorder handle for managing HTTP request/response recordings
///
/// A `Recorder` is a handle to an OTP actor process that manages recording state.
/// Multiple HTTP requests can share the same recorder by passing the same handle.
/// The recorder handles saving recordings to disk, loading them for playback,
/// and matching requests to recorded responses.
///
/// ## Thread Safety
///
/// Recorders are safe to use concurrently - multiple requests can use the same
/// recorder handle simultaneously. The internal actor processes messages sequentially.
///
/// ## Lifecycle
///
/// 1. Create with `recorder.start(mode, matching)`
/// 2. Attach to requests with `client.recorder(rec)`
/// 3. Optionally cleanup with `recorder.stop(rec)` (recordings already saved)
///
/// ## Examples
///
/// ```gleam
/// // Record mode
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// // Use recorder with requests
/// client.new
///   |> client.host("api.example.com")
///   |> client.recorder(rec)
///   |> client.send()
///
/// // Cleanup (optional - recordings already saved)
/// recorder.stop(rec)
/// ```
pub opaque type Recorder {
  Recorder(subject: process.Subject(RecorderMessage))
}

/// Recorder operating mode
///
/// Determines how the recorder behaves when attached to HTTP requests.
///
/// ## Variants
///
/// - `Record(directory)`: Capture real HTTP requests/responses and save to disk
/// - `Playback(directory)`: Return recorded responses without making network calls
/// - `Passthrough`: Make real requests without recording or playback
///
/// ## Examples
///
/// ```gleam
/// // Record real API calls
/// let record_mode = recorder.Record(directory: "mocks/api")
///
/// // Playback recorded responses
/// let playback_mode = recorder.Playback(directory: "mocks/api")
///
/// // No recording or playback
/// let passthrough_mode = recorder.Passthrough
/// ```
pub type Mode {
  Record(directory: String)
  Playback(directory: String)
  Passthrough
}

/// Recorder process state
type RecorderState {
  RecorderState(
    mode: Mode,
    directory: String,
    matching: matching.MatchingConfig,
    recordings: dict.Dict(String, recording.Recording),
  )
}

/// Start a new recorder in the specified mode
///
/// Creates an OTP actor process to manage recorder state. The recorder handles
/// saving recordings to disk (Record mode), loading them for playback (Playback mode),
/// or passing requests through unchanged (Passthrough mode).
///
/// ## Parameters
///
/// - `mode`: The operating mode (Record, Playback, or Passthrough)
/// - `matching_config`: Configuration for matching requests to recordings
///
/// ## Returns
///
/// - `Ok(Recorder)`: Successfully started recorder
/// - `Error(String)`: Error message if startup fails (e.g., cannot load recordings in Playback mode)
///
/// ## Examples
///
/// ```gleam
/// // Record mode - captures and saves requests/responses
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks/api"),
///   matching: matching.match_url_only(),
/// )
///
/// // Playback mode - returns recorded responses
/// let assert Ok(playback_rec) = recorder.start(
///   mode: recorder.Playback(directory: "mocks/api"),
///   matching: matching.match_url_only(),
/// )
///
/// // Passthrough mode - no recording or playback
/// let assert Ok(passthrough_rec) = recorder.start(
///   mode: recorder.Passthrough,
///   matching: matching.match_url_only(),
/// )
/// ```
///
/// ## Notes
///
/// - In Playback mode, recordings are loaded from disk at startup
/// - In Record mode, recordings are saved immediately when captured (no need to call `stop()`)
/// - Multiple requests can share the same recorder handle safely
/// - The recorder process runs until `stop()` is called or the VM shuts down
pub fn start(
  mode: Mode,
  matching_config: matching.MatchingConfig,
) -> Result(Recorder, String) {
  let directory = get_directory(mode)
  let initial_state =
    RecorderState(
      mode: mode,
      directory: directory,
      matching: matching_config,
      recordings: dict.new(),
    )

  // Load existing recordings if in playback mode
  case mode {
    Playback(dir) -> {
      case storage.load_recordings(dir) {
        Ok(loaded) -> {
          let recordings_map = build_recordings_map(loaded, matching_config)
          let state_with_recordings =
            RecorderState(
              mode: mode,
              directory: dir,
              matching: matching_config,
              recordings: recordings_map,
            )
          actor.new(state_with_recordings)
          |> actor.on_message(handle_recorder_message)
          |> actor.start
          |> result.map(wrap_recorder_subject)
          |> result.map_error(convert_actor_error)
        }
        Error(load_error) -> {
          Error("Failed to load recordings in playback mode: " <> load_error)
        }
      }
    }
    _ -> {
      actor.new(initial_state)
      |> actor.on_message(handle_recorder_message)
      |> actor.start
      |> result.map(wrap_recorder_subject)
      |> result.map_error(convert_actor_error)
    }
  }
}

fn wrap_recorder_subject(
  started: actor.Started(process.Subject(RecorderMessage)),
) -> Recorder {
  Recorder(subject: started.data)
}

fn convert_actor_error(error: actor.StartError) -> String {
  "Failed to start recorder: " <> string.inspect(error)
}

fn get_directory(mode: Mode) -> String {
  case mode {
    Record(dir) -> dir
    Playback(dir) -> dir
    Passthrough -> ""
  }
}

fn build_recordings_map(
  recordings: List(recording.Recording),
  config: matching.MatchingConfig,
) -> dict.Dict(String, recording.Recording) {
  list.fold(recordings, dict.new(), fn(acc, rec) {
    let signature = matching.build_signature(rec.request, config)
    dict.insert(acc, signature, rec)
  })
}

fn handle_recorder_message(
  state: RecorderState,
  message: RecorderMessage,
) -> Next(RecorderState, RecorderMessage) {
  case message {
    AddRecording(rec) -> {
      let signature = matching.build_signature(rec.request, state.matching)
      let new_recordings = dict.insert(state.recordings, signature, rec)
      let new_state =
        RecorderState(
          mode: state.mode,
          directory: state.directory,
          matching: state.matching,
          recordings: new_recordings,
        )

      // Save immediately if in Record mode
      case state.mode {
        Record(dir) -> {
          case storage.save_recording_immediately(dir, rec, state.matching) {
            Ok(_) -> actor.continue(new_state)
            Error(save_error) -> {
              // Log error but don't crash - keep in-memory recording
              io.println_error("Failed to save recording: " <> save_error)
              actor.continue(new_state)
            }
          }
        }
        _ -> actor.continue(new_state)
      }
    }
    FindRecording(request, reply_to) -> {
      let signature = matching.build_signature(request, state.matching)
      case dict.get(state.recordings, signature) {
        Ok(recording_value) -> {
          process.send(reply_to, FoundRecording(option.Some(recording_value)))
          actor.continue(state)
        }
        Error(not_found) -> {
          // Recording not found in dict - this is normal in playback mode.
          // Bind the error for clarity but do not treat it as a failure.
          let _unused_not_found = not_found
          process.send(reply_to, FoundRecording(option.None))
          actor.continue(state)
        }
      }
    }
    GetRecordings(reply_to) -> {
      let all_recordings = dict.values(state.recordings)
      process.send(reply_to, GotRecordings(all_recordings))
      actor.continue(state)
    }
    CheckMode(reply_to) -> {
      let is_record = case state.mode {
        Record(_) -> True
        _ -> False
      }
      process.send(reply_to, ModeIsRecord(is_record))
      actor.continue(state)
    }
    Stop(reply_to) -> {
      // No need to save - recordings already saved immediately
      process.send(reply_to, Stopped(Ok(Nil)))
      actor.stop()
    }
  }
}

type RecorderMessage {
  AddRecording(recording: recording.Recording)
  FindRecording(
    request: recording.RecordedRequest,
    reply_to: process.Subject(RecorderResponse),
  )
  GetRecordings(reply_to: process.Subject(RecorderResponse))
  CheckMode(reply_to: process.Subject(RecorderResponse))
  Stop(reply_to: process.Subject(RecorderResponse))
}

type RecorderResponse {
  FoundRecording(option.Option(recording.Recording))
  GotRecordings(List(recording.Recording))
  ModeIsRecord(Bool)
  Stopped(Result(Nil, String))
}

/// Add a recording to the recorder
///
/// Manually adds a recording to the recorder's in-memory state and saves it to disk
/// immediately if in Record mode. This function is typically called automatically
/// by the HTTP client when a request completes, but can be used directly for testing
/// or manual recording creation.
///
/// ## Parameters
///
/// - `recorder`: The recorder to add the recording to
/// - `rec`: The recording (request/response pair) to add
///
/// ## Behavior by Mode
///
/// - **Record mode**: Adds to in-memory state and saves to disk immediately
/// - **Playback mode**: No-op (recordings loaded from disk at startup)
/// - **Passthrough mode**: No-op (no recording functionality)
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// // Manually add a recording
/// let manual_recording = recording.Recording(
///   request: create_test_request(),
///   response: create_test_response(),
/// )
/// recorder.add_recording(rec, manual_recording)
/// ```
///
/// ## Notes
///
/// - Recordings are saved immediately in Record mode (no need to call `stop()`)
/// - If save fails, error is logged but recording remains in memory
/// - Duplicate recordings (same signature) overwrite previous ones
pub fn add_recording(recorder: Recorder, rec: recording.Recording) -> Nil {
  let Recorder(subject) = recorder
  process.send(subject, AddRecording(rec))
}

/// Check if recorder is in Record mode
///
/// Determines whether the recorder is configured to capture and save real HTTP
/// requests/responses. Useful for conditional logic that only applies during recording.
///
/// ## Parameters
///
/// - `recorder`: The recorder to check
///
/// ## Returns
///
/// - `True`: Recorder is in Record mode
/// - `False`: Recorder is in Playback or Passthrough mode
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// if recorder.is_record_mode(rec) {
///   io.println("Recording mode active")
/// }
/// ```
///
/// ## Notes
///
/// - Returns `False` if the recorder process doesn't respond (safe default)
/// - Timeout is 1 second - recorder should respond quickly
pub fn is_record_mode(recorder: Recorder) -> Bool {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, CheckMode(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, identity_recorder_response)

  case process.selector_receive(selector, 1000) {
    Ok(ModeIsRecord(is_record)) -> is_record
    Ok(unexpected_message) -> {
      // Received wrong message type - recorder is broken. Log the
      // unexpected message and return False as a safe default.
      io.println_error(
        "Recorder returned unexpected response to CheckMode: "
        <> string.inspect(unexpected_message),
      )
      False
    }
    Error(timeout_error) -> {
      // Process timeout (1 second) - recorder is not responding. Log the
      // timeout and return False as a safe default.
      io.println_error(
        "Recorder did not respond to CheckMode within 1 second: "
        <> string.inspect(timeout_error),
      )
      False
    }
  }
}

fn identity_recorder_response(response: RecorderResponse) -> RecorderResponse {
  response
}

/// Find a matching recording for a request
///
/// Searches for a recording that matches the given request based on the recorder's
/// matching configuration. This is used internally by the HTTP client during playback,
/// but can be called directly to check if a recording exists.
///
/// ## Parameters
///
/// - `recorder`: The recorder to search in
/// - `request`: The request to find a matching recording for
///
/// ## Returns
///
/// - `Some(Recording)`: Matching recording found
/// - `None`: No matching recording found (or not in Playback mode)
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Playback(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// let request = recording.RecordedRequest(
///   method: http.Get,
///   scheme: http.Https,
///   host: "api.example.com",
///   port: option.None,
///   path: "/users",
///   query: option.None,
///   headers: [],
///   body: "",
/// )
///
/// case recorder.find_recording(rec, request) {
///   Some(recording) -> io.println("Found recording")
///   None -> io.println("No recording found")
/// }
/// ```
///
/// ## Notes
///
/// - Only works in Playback mode (returns `None` in other modes)
/// - Matching uses the recorder's `MatchingConfig` (method, URL, headers, body)
/// - Returns `None` if recorder doesn't respond (safe default)
/// - Timeout is 1 second - recorder should respond quickly
pub fn find_recording(
  recorder: Recorder,
  request: recording.RecordedRequest,
) -> option.Option(recording.Recording) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, FindRecording(request, reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, identity_recorder_response)

  case process.selector_receive(selector, 1000) {
    Ok(FoundRecording(rec_opt)) -> rec_opt
    Ok(unexpected_message) -> {
      // Received wrong message type - recorder is broken. Log the
      // unexpected message and return None as a safe default.
      io.println_error(
        "Recorder returned unexpected response to FindRecording: "
        <> string.inspect(unexpected_message),
      )
      option.None
    }
    Error(timeout_error) -> {
      // Process timeout (1 second) - recorder is not responding. Log the
      // timeout and return None as a safe default.
      io.println_error(
        "Recorder did not respond to FindRecording within 1 second: "
        <> string.inspect(timeout_error),
      )
      option.None
    }
  }
}

/// Get all recordings from the recorder
///
/// Retrieves all recordings currently stored in the recorder's in-memory state.
/// In Playback mode, this returns all recordings loaded from disk at startup.
/// In Record mode, this returns all recordings captured so far (including unsaved ones).
///
/// ## Parameters
///
/// - `recorder`: The recorder to get recordings from
///
/// ## Returns
///
/// - `List(Recording)`: All recordings in the recorder (empty list if none or error)
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// // Make some requests...
///
/// let recordings = recorder.get_recordings(rec)
/// io.println("Captured " <> int.to_string(list.length(recordings)) <> " recordings")
/// ```
///
/// ## Notes
///
/// - Returns empty list if recorder doesn't respond (safe default)
/// - In Record mode, includes recordings that may not yet be saved to disk
/// - Timeout is 1 second - recorder should respond quickly
pub fn get_recordings(recorder: Recorder) -> List(recording.Recording) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, GetRecordings(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, identity_recorder_response)

  case process.selector_receive(selector, 1000) {
    Ok(GotRecordings(recordings)) -> recordings
    Ok(unexpected_message) -> {
      // Received wrong message type - recorder is broken. Log the
      // unexpected message and return an empty list as a safe default.
      io.println_error(
        "Recorder returned unexpected response to GetRecordings: "
        <> string.inspect(unexpected_message),
      )
      []
    }
    Error(timeout_error) -> {
      // Process timeout (1 second) - recorder is not responding. Log the
      // timeout and return an empty list as a safe default.
      io.println_error(
        "Recorder did not respond to GetRecordings within 1 second: "
        <> string.inspect(timeout_error),
      )
      []
    }
  }
}

/// Stop the recorder and cleanup
///
/// Stops the recorder's OTP actor process and releases resources. In Record mode,
/// recordings are already saved to disk immediately when captured, so this function
/// only performs cleanup. Calling `stop()` is optional but recommended for proper
/// resource management.
///
/// ## Parameters
///
/// - `recorder`: The recorder to stop
///
/// ## Returns
///
/// - `Ok(Nil)`: Successfully stopped the recorder
/// - `Error(String)`: Error message if the recorder doesn't respond within 5 seconds
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(rec) = recorder.start(
///   mode: recorder.Record(directory: "mocks"),
///   matching: matching.match_url_only(),
/// )
///
/// // Use recorder...
///
/// // Cleanup (optional - recordings already saved)
/// case recorder.stop(rec) {
///   Ok(_) -> io.println("Recorder stopped")
///   Error(reason) -> io.println_error("Failed to stop: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Recordings are saved immediately when captured - `stop()` is not required for persistence
/// - This function is optional but recommended for proper resource cleanup
/// - Timeout is 5 seconds - recorder should stop quickly
/// - After calling `stop()`, the recorder handle is no longer valid
pub fn stop(recorder: Recorder) -> Result(Nil, String) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, Stop(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, identity_recorder_response)

  case process.selector_receive(selector, 5000) {
    Ok(Stopped(result)) -> result
    Ok(unexpected_message) -> {
      Error(
        "Unexpected response from recorder: "
        <> string.inspect(unexpected_message),
      )
    }
    Error(timeout_error) -> {
      // Process timeout (5 seconds) - recorder is not responding. Include the
      // timeout error details in the message.
      Error(
        "Recorder did not respond within 5 seconds: "
        <> string.inspect(timeout_error),
      )
    }
  }
}
