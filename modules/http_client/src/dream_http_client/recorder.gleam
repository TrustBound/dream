//// Recorder process and state management
////
//// Manages HTTP request/response recordings using a process to store state.
//// Supports recording, playback, and passthrough modes.

import dream_http_client/matching
import dream_http_client/recording
import dream_http_client/storage
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor.{type Next}
import gleam/result
import gleam/string

/// Opaque recorder handle - contains subject for state management
pub opaque type Recorder {
  Recorder(subject: process.Subject(RecorderMessage))
}

/// Recorder mode
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
/// Creates a process to manage recorder state internally.
/// Multiple requests can share the same recorder by passing the same handle.
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
      actor.continue(new_state)
    }
    FindRecording(request, reply_to) -> {
      let signature = matching.build_signature(request, state.matching)
      case dict.get(state.recordings, signature) {
        Ok(rec) -> {
          process.send(reply_to, FoundRecording(option.Some(rec)))
          actor.continue(state)
        }
        Error(_not_found) -> {
          // Recording not found in dict - this is normal in playback mode
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
      // Save recordings if in Record mode
      case state.mode {
        Record(dir) -> {
          let all_recordings = dict.values(state.recordings)
          case storage.save_recordings(dir, all_recordings) {
            Ok(_) -> {
              process.send(reply_to, Stopped(Ok(Nil)))
            }
            Error(reason) -> {
              process.send(reply_to, Stopped(Error(reason)))
            }
          }
        }
        _ -> {
          // No save needed for Playback or Passthrough
          process.send(reply_to, Stopped(Ok(Nil)))
        }
      }
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
/// Only works in Record mode. In other modes, this is a no-op.
pub fn add_recording(recorder: Recorder, rec: recording.Recording) -> Nil {
  let Recorder(subject) = recorder
  process.send(subject, AddRecording(rec))
}

/// Check if recorder is in Record mode
///
/// Returns true if the recorder is in Record mode, false otherwise.
pub fn is_record_mode(recorder: Recorder) -> Bool {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, CheckMode(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, fn(msg) { msg })

  case process.selector_receive(selector, 1000) {
    Ok(ModeIsRecord(is_record)) -> is_record
    Ok(_unexpected_message) -> {
      // Received wrong message type - recorder is broken
      // Return False as safe default
      False
    }
    Error(_timeout) -> {
      // Process timeout (1 second) - recorder is not responding
      // Return False as safe default
      False
    }
  }
}

/// Find a matching recording for a request
///
/// Returns the matching recording if found, or None if not found.
/// Only works in Playback mode. In other modes, returns None.
pub fn find_recording(
  recorder: Recorder,
  request: recording.RecordedRequest,
) -> option.Option(recording.Recording) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, FindRecording(request, reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, fn(msg) { msg })

  case process.selector_receive(selector, 1000) {
    Ok(FoundRecording(rec_opt)) -> rec_opt
    Ok(_unexpected_message) -> {
      // Received wrong message type - recorder is broken
      // Return None as safe default
      option.None
    }
    Error(_timeout) -> {
      // Process timeout (1 second) - recorder is not responding
      // Return None as safe default
      option.None
    }
  }
}

/// Get all recordings from the recorder
///
/// Returns all recordings currently stored in the recorder.
pub fn get_recordings(recorder: Recorder) -> List(recording.Recording) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, GetRecordings(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, fn(msg) { msg })

  case process.selector_receive(selector, 1000) {
    Ok(GotRecordings(recordings)) -> recordings
    Ok(_unexpected_message) -> {
      // Received wrong message type - recorder is broken
      // Return empty list as safe default
      []
    }
    Error(_timeout) -> {
      // Process timeout (1 second) - recorder is not responding
      // Return empty list as safe default
      []
    }
  }
}

/// Stop the recorder and save recordings
///
/// In Record mode, saves all recordings to disk before stopping.
/// In other modes, just stops the process.
/// Returns an error if saving fails.
pub fn stop(recorder: Recorder) -> Result(Nil, String) {
  let Recorder(subject) = recorder
  let reply_subject = process.new_subject()
  process.send(subject, Stop(reply_subject))

  let selector =
    process.new_selector()
    |> process.select_map(reply_subject, fn(msg) { msg })

  case process.selector_receive(selector, 5000) {
    Ok(Stopped(result)) -> result
    Ok(unexpected_message) -> {
      Error(
        "Unexpected response from recorder: "
        <> string.inspect(unexpected_message),
      )
    }
    Error(_timeout) -> {
      // Process timeout (5 seconds) - recorder is not responding
      Error("Recorder did not respond within 5 seconds")
    }
  }
}
