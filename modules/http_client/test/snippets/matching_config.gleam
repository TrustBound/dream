//// README: Request Matching
////
//// Builds a request key that ignores headers and body, and starts a
//// playback recorder with it.

import dream_http_client/matching
import dream_http_client/recorder.{type Recorder, directory, key, mode, start}

// Build a request key function from include/exclude flags
pub fn method_and_url_key() -> matching.MatchKey {
  matching.request_key(
    method: True,
    url: True,
    // Ignore auth tokens, timestamps
    headers: False,
    // Ignore request IDs in body
    body: False,
  )
}

pub fn start_playback(
  recordings_directory: String,
) -> Result(Recorder, String) {
  recorder.new()
  |> directory(recordings_directory)
  |> mode("playback")
  |> key(method_and_url_key())
  |> start()
}
