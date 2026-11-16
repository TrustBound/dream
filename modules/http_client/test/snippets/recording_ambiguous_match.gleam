//// README: Ambiguous Matches (Key Collisions)
////
//// A key that ignores headers and body. When two recordings share that key,
//// a lookup returns an "Ambiguous recording match" error.

import dream_http_client/matching
import dream_http_client/recorder.{type Recorder, directory, key, mode, start}

// A lookup through this recorder returns Error("Ambiguous recording match ...")
// when more than one recording matches the request key
pub fn start_playback(
  recordings_directory: String,
) -> Result(Recorder, String) {
  let request_key_fn =
    matching.request_key(method: True, url: True, headers: False, body: False)

  recorder.new()
  |> directory(recordings_directory)
  |> mode("playback")
  |> key(request_key_fn)
  |> start()
}
