//// README: Scrubbing Secrets, response transformer
////
//// A response transformer removes set-cookie headers and the body before
//// the recording is written to disk. It runs only in record mode.

import dream_http_client/recorder.{
  type Recorder, directory, mode, response_transformer, start,
}
import dream_http_client/recording
import gleam/list

pub fn scrub_response(
  _request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  case response {
    recording.BlockingResponse(status, headers, _body) ->
      recording.BlockingResponse(
        status: status,
        headers: list.filter(headers, is_not_set_cookie),
        body: "",
      )

    recording.StreamingResponse(status, headers, chunks) ->
      recording.StreamingResponse(
        status: status,
        headers: list.filter(headers, is_not_set_cookie),
        chunks: chunks,
      )
  }
}

fn is_not_set_cookie(header: #(String, String)) -> Bool {
  header.0 != "set-cookie"
}

pub fn start_scrubbing_recorder(
  recordings_directory: String,
) -> Result(Recorder, String) {
  recorder.new()
  |> directory(recordings_directory)
  |> mode("record")
  |> response_transformer(scrub_response)
  |> start()
}
