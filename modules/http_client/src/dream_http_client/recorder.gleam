//// Recorder process and state management
////
//// Manages HTTP request/response recordings using a process to store state.
//// Supports recording, playback, and passthrough modes.

import dream_http_client/matching
import dream_http_client/recording
import dream_http_client/storage
import gleam/dict
import gleam/erlang/process
import gleam/int
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
/// 1. Build with `recorder.new() |> ... |> start()`
/// 2. Attach to requests with `client.recorder(rec)`
/// 3. Optionally cleanup with `recorder.stop(rec)` (recordings already saved)
///
/// ## Examples
///
/// ```gleam
/// import dream_http_client/recorder.{directory, mode, start}
///
/// // Record mode
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("record")
///   |> start()
///
/// // Use recorder with requests
/// client.new()
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

/// A request transformer applied before keying and persistence.
///
/// A transformer is a pure function `RecordedRequest -> RecordedRequest` that
/// runs in two places:
///
/// - Before computing the match key (so matching uses the transformed request)
/// - Before persisting recordings to disk (so secrets can be removed)
///
/// This is how you implement “scrub secrets and still match”: normalize the
/// request (remove auth headers, drop query params, normalize paths, etc.),
/// then choose a key that matches on the remaining stable fields.
///
/// ## Example (drop Authorization header)
///
/// ```gleam
/// import dream_http_client/recorder.{directory, mode, request_transformer}
/// import dream_http_client/recording
/// import gleam/list
///
/// fn drop_auth_header(req: recording.RecordedRequest) -> recording.RecordedRequest {
///   let headers =
///     req.headers
///     |> list.filter(fn(h) { h.0 != "Authorization" })
///   recording.RecordedRequest(..req, headers: headers)
/// }
///
/// let builder =
///   recorder.new()
///   |> mode("record")
///   |> directory("mocks")
///   |> request_transformer(drop_auth_header)
/// ```
pub type RequestTransformer =
  fn(recording.RecordedRequest) -> recording.RecordedRequest

/// A response transformer applied before persistence in Record mode.
///
/// This hook is for scrubbing secrets out of recorded responses (set-cookie,
/// authorization echoes, PII, etc.) before they are written to disk.
///
/// **Order of operations in Record mode:**
///
/// 1. The request transformer runs (request normalization + request scrubbing)
/// 2. The key is computed from the transformed request
/// 3. The response transformer runs (response scrubbing)
/// 4. The scrubbed recording is stored in memory and persisted to disk
///
/// Note: this transformer runs **only in Record mode**. Playback returns
/// whatever is in the saved fixtures.
pub type ResponseTransformer =
  fn(recording.RecordedRequest, recording.RecordedResponse) ->
    recording.RecordedResponse

/// Builder for configuring and starting a recorder.
///
/// Recorder configuration uses a builder so options can evolve without adding a
/// combinatorial set of `start_with_*` functions.
///
/// ```gleam
/// import dream_http_client/recorder.{directory, mode}
///
/// let builder =
///   recorder.new()
///   |> directory("mocks/api")
///   |> mode("playback")
/// ```
pub type RecorderBuilder {
  RecorderBuilder(
    mode: String,
    directory: option.Option(String),
    key: matching.MatchKey,
    request_transformer: RequestTransformer,
    response_transformer: ResponseTransformer,
  )
}

/// Create a new recorder builder with safe defaults.
///
/// Defaults:
/// - `mode`: `"passthrough"`
/// - `directory`: unset
/// - `key`: `matching.request_key(method: True, url: True, headers: False, body: False)`
/// - `request_transformer`: identity
/// - `response_transformer`: identity
pub fn new() -> RecorderBuilder {
  RecorderBuilder(
    mode: "passthrough",
    directory: option.None,
    key: matching.request_key(
      method: True,
      url: True,
      headers: False,
      body: False,
    ),
    request_transformer: identity_request_transformer,
    response_transformer: identity_response_transformer,
  )
}

/// Set the recording directory used by `"record"` and `"playback"` modes.
///
/// The directory is **required** for `"record"` and `"playback"` (validated in
/// `start()`), and ignored for `"passthrough"`.
pub fn directory(builder: RecorderBuilder, directory: String) -> RecorderBuilder {
  RecorderBuilder(..builder, directory: option.Some(directory))
}

/// Set the recorder mode string.
///
/// Valid modes (validated in `start()`):
/// - `"record"`
/// - `"playback"`
/// - `"passthrough"`
///
/// Mode strings are case-sensitive.
pub fn mode(builder: RecorderBuilder, mode: String) -> RecorderBuilder {
  RecorderBuilder(..builder, mode: mode)
}

/// Set the match key function.
///
/// The key function determines how requests are grouped for playback lookup.
/// Keys should be stable and should generally **not** include secrets.
///
/// If two different recordings produce the same key, playback lookup becomes
/// ambiguous and `find_recording()` will return `Error(...)`.
pub fn key(builder: RecorderBuilder, key: matching.MatchKey) -> RecorderBuilder {
  RecorderBuilder(..builder, key: key)
}

/// Set the request transformer.
///
/// The transformer is applied before keying *and* before persistence, so it’s
/// the right place to normalize requests and scrub secrets.
pub fn request_transformer(
  builder: RecorderBuilder,
  request_transformer: RequestTransformer,
) -> RecorderBuilder {
  RecorderBuilder(..builder, request_transformer: request_transformer)
}

/// Set the response transformer.
///
/// This transformer is applied **only in Record mode** and runs before
/// persistence so recorded fixtures can be safely committed/shared.
pub fn response_transformer(
  builder: RecorderBuilder,
  response_transformer: ResponseTransformer,
) -> RecorderBuilder {
  RecorderBuilder(..builder, response_transformer: response_transformer)
}

fn identity_request_transformer(
  request: recording.RecordedRequest,
) -> recording.RecordedRequest {
  request
}

fn identity_response_transformer(
  _request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  response
}

/// Recorder process state
type RecorderState {
  RecorderState(
    mode: RecorderMode,
    directory: String,
    key: matching.MatchKey,
    request_transformer: RequestTransformer,
    response_transformer: ResponseTransformer,
    recordings: dict.Dict(String, List(recording.Recording)),
  )
}

type RecorderMode {
  Record
  Playback
  Passthrough
}

/// Start a new recorder from a builder.
///
/// Creates an OTP actor process to manage recorder state. The recorder handles
/// saving recordings to disk (Record mode), loading them for playback (Playback mode),
/// or passing requests through unchanged (Passthrough mode).
///
/// ## Parameters
///
/// - `builder`: Recorder configuration builder
///
/// ## Returns
///
/// - `Ok(Recorder)`: Successfully started recorder
/// - `Error(String)`: Error message if startup fails (e.g., cannot load recordings in Playback mode)
///
/// ## Examples
///
/// ```gleam
/// import dream_http_client/recorder.{directory, mode, start}
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks/api")
///   |> mode("playback")
///   |> start()
/// ```
///
/// ## Notes
///
/// - In Playback mode, recordings are loaded from disk at startup
/// - In Record mode, recordings are saved immediately when captured (no need to call `stop()`)
/// - Multiple requests can share the same recorder handle safely
/// - The recorder process runs until `stop()` is called or the VM shuts down
pub fn start(builder: RecorderBuilder) -> Result(Recorder, String) {
  let mode = parse_mode(builder.mode)
  let directory = resolve_directory(mode, builder.directory)

  case mode, directory {
    Error(e), _ -> Error(e)
    _, Error(e) -> Error(e)
    Ok(parsed_mode), Ok(dir) -> {
      let initial_state =
        RecorderState(
          mode: parsed_mode,
          directory: dir,
          key: builder.key,
          request_transformer: builder.request_transformer,
          response_transformer: builder.response_transformer,
          recordings: dict.new(),
        )

      case parsed_mode {
        Playback -> {
          case storage.load_recordings(dir) {
            Ok(loaded) -> {
              let recordings_map =
                build_recordings_map(
                  loaded,
                  builder.key,
                  builder.request_transformer,
                )
              let state_with_recordings =
                RecorderState(
                  mode: parsed_mode,
                  directory: dir,
                  key: builder.key,
                  request_transformer: builder.request_transformer,
                  response_transformer: builder.response_transformer,
                  recordings: recordings_map,
                )
              actor.new(state_with_recordings)
              |> actor.on_message(handle_recorder_message)
              |> actor.start
              |> result.map(wrap_recorder_subject)
              |> result.map_error(convert_actor_error)
            }
            Error(load_error) ->
              Error(
                "Failed to load recordings in playback mode: " <> load_error,
              )
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

fn build_recordings_map(
  recordings: List(recording.Recording),
  key: matching.MatchKey,
  request_transformer: RequestTransformer,
) -> dict.Dict(String, List(recording.Recording)) {
  list.fold(recordings, dict.new(), fn(acc, rec) {
    let transformed = transform_recording_request(rec, request_transformer)
    let signature = key(transformed.request)
    case dict.get(acc, signature) {
      Ok(existing) -> dict.insert(acc, signature, [transformed, ..existing])
      Error(_) -> dict.insert(acc, signature, [transformed])
    }
  })
}

fn transform_recording_request(
  rec: recording.Recording,
  request_transformer: RequestTransformer,
) -> recording.Recording {
  let recording.Recording(request, response) = rec
  let request2 = request_transformer(request)
  recording.Recording(request: request2, response: response)
}

fn transform_recording_for_persistence(
  rec: recording.Recording,
  request_transformer: RequestTransformer,
  response_transformer: ResponseTransformer,
) -> recording.Recording {
  let recording.Recording(request, response) = rec
  let request2 = request_transformer(request)
  let response2 = response_transformer(request2, response)
  recording.Recording(request: request2, response: response2)
}

fn parse_mode(mode: String) -> Result(RecorderMode, String) {
  case mode {
    "record" -> Ok(Record)
    "playback" -> Ok(Playback)
    "passthrough" -> Ok(Passthrough)
    _ ->
      Error(
        "Unknown recorder mode: "
        <> mode
        <> ". Expected one of: record, playback, passthrough",
      )
  }
}

fn resolve_directory(
  mode: Result(RecorderMode, String),
  directory: option.Option(String),
) -> Result(String, String) {
  case mode {
    Error(e) -> Error(e)
    Ok(Record) | Ok(Playback) -> {
      case directory {
        option.Some(dir) -> Ok(dir)
        option.None ->
          Error("Recorder directory is required for record/playback")
      }
    }
    Ok(Passthrough) -> Ok("")
  }
}

fn handle_recorder_message(
  state: RecorderState,
  message: RecorderMessage,
) -> Next(RecorderState, RecorderMessage) {
  case message {
    AddRecording(rec) -> {
      case state.mode {
        Record -> {
          let transformed =
            transform_recording_for_persistence(
              rec,
              state.request_transformer,
              state.response_transformer,
            )
          let key = state.key(transformed.request)

          let new_recordings = case dict.get(state.recordings, key) {
            Ok(existing) ->
              dict.insert(state.recordings, key, [transformed, ..existing])
            Error(_) -> dict.insert(state.recordings, key, [transformed])
          }

          let new_state =
            RecorderState(
              mode: state.mode,
              directory: state.directory,
              key: state.key,
              request_transformer: state.request_transformer,
              response_transformer: state.response_transformer,
              recordings: new_recordings,
            )

          // Save immediately if in Record mode
          case
            storage.save_recording_immediately(
              state.directory,
              transformed,
              key,
            )
          {
            Ok(_) -> actor.continue(new_state)
            Error(save_error) -> {
              // Log error but don't crash - keep in-memory recording
              io.println_error("Failed to save recording: " <> save_error)
              actor.continue(new_state)
            }
          }
        }
        _ -> actor.continue(state)
      }
    }
    FindRecording(request, reply_to) -> {
      case state.mode {
        Playback -> {
          let transformed_request = state.request_transformer(request)
          let key = state.key(transformed_request)
          case dict.get(state.recordings, key) {
            Error(_) -> {
              process.send(reply_to, FoundRecording(Ok(option.None)))
              actor.continue(state)
            }
            Ok([]) -> {
              // Should not happen, but treat as not found
              process.send(reply_to, FoundRecording(Ok(option.None)))
              actor.continue(state)
            }
            Ok([rec]) -> {
              process.send(reply_to, FoundRecording(Ok(option.Some(rec))))
              actor.continue(state)
            }
            Ok(records) -> {
              let count = list.length(records)
              process.send(
                reply_to,
                FoundRecording(Error(
                  "Ambiguous recording match for key: "
                  <> key
                  <> " ("
                  <> int.to_string(count)
                  <> " recordings)",
                )),
              )
              actor.continue(state)
            }
          }
        }
        _ -> {
          // Not in playback mode: never return recordings
          process.send(reply_to, FoundRecording(Ok(option.None)))
          actor.continue(state)
        }
      }
    }
    GetRecordings(reply_to) -> {
      let all_recordings = flatten_recordings(dict.values(state.recordings))
      process.send(reply_to, GotRecordings(all_recordings))
      actor.continue(state)
    }
    CheckMode(reply_to) -> {
      let is_record = case state.mode {
        Record -> True
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
  FoundRecording(Result(option.Option(recording.Recording), String))
  GotRecordings(List(recording.Recording))
  ModeIsRecord(Bool)
  Stopped(Result(Nil, String))
}

fn flatten_recordings(
  lists: List(List(recording.Recording)),
) -> List(recording.Recording) {
  // Flatten while preserving order within each list as stored (newest-first).
  list.fold(lists, [], fn(acc, recs) {
    list.fold(recs, acc, fn(acc2, r) { [r, ..acc2] })
  })
  |> list.reverse
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
/// import dream_http_client/recorder.{directory, mode, start}
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("record")
///   |> start()
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
/// - If multiple recordings share the same match key, they are all stored
///   (playback lookup will error if that makes the key ambiguous)
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
/// import dream_http_client/recorder.{directory, mode, start}
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("record")
///   |> start()
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
/// configured match key and request transformer. This is used internally by the HTTP client
/// during playback, but can be called directly to check if a recording exists.
///
/// ## Parameters
///
/// - `recorder`: The recorder to search in
/// - `request`: The request to find a matching recording for
///
/// ## Returns
///
/// - `Ok(Some(Recording))`: Matching recording found (unambiguous)
/// - `Ok(None)`: No matching recording found (or not in Playback mode)
/// - `Error(String)`: Playback lookup was ambiguous (multiple recordings share the same key)
///
/// ## Examples
///
/// ```gleam
/// import dream_http_client/recorder.{directory, mode, start}
/// import gleam/http
/// import gleam/option
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("playback")
///   |> start()
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
///   Ok(option.Some(_recording)) -> io.println("Found recording")
///   Ok(option.None) -> io.println("No recording found")
///   Error(reason) -> io.println_error("Ambiguous match: " <> reason)
/// }
/// ```
///
/// ## Notes
///
/// - Only works in Playback mode (returns `None` in other modes)
/// - Matching uses the recorder's configured key + request transformer
/// - Returns `None` if recorder doesn't respond (safe default)
/// - Timeout is 1 second - recorder should respond quickly
pub fn find_recording(
  recorder: Recorder,
  request: recording.RecordedRequest,
) -> Result(option.Option(recording.Recording), String) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, FindRecording(request, reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, identity_recorder_response)

  case process.selector_receive(selector, 1000) {
    Ok(FoundRecording(result)) -> result
    Ok(unexpected_message) -> {
      // Received wrong message type - recorder is broken. Log the
      // unexpected message and return None as a safe default.
      io.println_error(
        "Recorder returned unexpected response to FindRecording: "
        <> string.inspect(unexpected_message),
      )
      Ok(option.None)
    }
    Error(timeout_error) -> {
      // Process timeout (1 second) - recorder is not responding. Log the
      // timeout and return None as a safe default.
      io.println_error(
        "Recorder did not respond to FindRecording within 1 second: "
        <> string.inspect(timeout_error),
      )
      Ok(option.None)
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
/// import dream_http_client/recorder.{directory, mode, start}
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("record")
///   |> start()
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
/// import dream_http_client/recorder.{directory, mode, start}
///
/// let assert Ok(rec) =
///   recorder.new()
///   |> directory("mocks")
///   |> mode("record")
///   |> start()
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
