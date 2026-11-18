//// README: Use Cases, Testing
////
//// Plays back the fixtures in test/fixtures/api, so tests need no network.

import dream_http_client/client.{
  type HttpResponse, type SendError, host, path, port, recorder as with_recorder,
  scheme, send,
}
import dream_http_client/recorder.{type Recorder, directory, mode, start}
import gleam/http

pub fn start_api_playback() -> Result(Recorder, String) {
  recorder.new()
  |> directory("test/fixtures/api")
  |> mode("playback")
  |> start()
}

// Tests run without external dependencies
pub fn fetch_recorded_text(
  playback_recorder: Recorder,
) -> Result(HttpResponse, SendError) {
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> with_recorder(playback_recorder)
  |> send()
}
