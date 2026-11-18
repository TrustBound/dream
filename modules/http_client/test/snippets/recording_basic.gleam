//// README: Recording & Playback, Quick Example
////
//// Records a real request, then plays it back with no network call.

import dream_http_client/client.{
  type HttpResponse, type SendError, host, path, port, recorder as with_recorder,
  scheme, send,
}
import dream_http_client/recorder.{directory, mode, start}
import gleam/http
import gleam/result

pub type RecordingError {
  RecorderFailed(reason: String)
  RequestFailed(error: SendError)
}

// Record real requests
pub fn record_text(
  recordings_directory: String,
) -> Result(HttpResponse, RecordingError) {
  use record_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory)
    |> mode("record")
    |> start()
    |> result.map_error(RecorderFailed),
  )

  let response =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/text")
    |> with_recorder(record_recorder)
    |> send()
    |> result.map_error(RequestFailed)

  // The recorder writes each recording in its own process. Stop returns
  // when every recording is on disk.
  use Nil <- result.try(
    recorder.stop(record_recorder)
    |> result.map_error(RecorderFailed),
  )
  response
}

// Playback later (no network)
pub fn play_back_text(
  recordings_directory: String,
) -> Result(HttpResponse, RecordingError) {
  use playback_recorder <- result.try(
    recorder.new()
    |> directory(recordings_directory)
    |> mode("playback")
    |> start()
    |> result.map_error(RecorderFailed),
  )

  // Returns the recorded response
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> with_recorder(playback_recorder)
  |> send()
  |> result.map_error(RequestFailed)
}
