//// Recording and Playback with start_stream()
////
//// Example showing how to record a streaming response and play it back
//// using the callback-based streaming API.
////
//// Note: Tests use localhost:9876 (mock server) instead of external APIs

import dream_http_client/client.{
  await_stream, host, on_stream_chunk, on_stream_end, on_stream_start, path,
  port, recorder as with_recorder, scheme, start_stream,
}
import dream_http_client/recorder.{directory, mode, start}
import gleam/bit_array
import gleam/erlang/process
import gleam/http
import gleam/result
import simplifile

pub fn record_and_playback_start_stream() -> Result(Bool, String) {
  let recordings_directory_path = "build/test_recordings_start_stream_snippet"

  // Clean up from previous runs
  let _ = simplifile.delete(recordings_directory_path)

  // 1. Record a real streaming request
  use rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("record")
    |> start(),
  )

  let record_subject = process.new_subject()

  use record_handle <- result.try(
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> with_recorder(rec)
    |> on_stream_start(fn(_headers) { Nil })
    |> on_stream_chunk(fn(data) {
      process.send(record_subject, bit_array.byte_size(data))
    })
    |> on_stream_end(fn(_headers) { process.send(record_subject, -1) })
    |> start_stream(),
  )

  await_stream(record_handle)
  let _ = recorder.stop(rec)

  let original_bytes = collect_sizes(record_subject, 0)

  case original_bytes > 0 {
    True -> Nil
    False -> panic as "No bytes received during recording"
  }

  // 2. Playback from recording (no network call)
  use playback_rec <- result.try(
    recorder.new()
    |> directory(recordings_directory_path)
    |> mode("playback")
    |> start(),
  )

  let playback_subject = process.new_subject()

  use playback_handle <- result.try(
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> with_recorder(playback_rec)
    |> on_stream_start(fn(_headers) { Nil })
    |> on_stream_chunk(fn(data) {
      process.send(playback_subject, bit_array.byte_size(data))
    })
    |> on_stream_end(fn(_headers) { process.send(playback_subject, -1) })
    |> start_stream(),
  )

  await_stream(playback_handle)
  let _ = recorder.stop(playback_rec)

  let playback_bytes = collect_sizes(playback_subject, 0)

  // Cleanup
  let _ = simplifile.delete(recordings_directory_path)

  // Verify playback returned data
  Ok(playback_bytes > 0 && playback_bytes == original_bytes)
}

fn collect_sizes(subject: process.Subject(Int), total: Int) -> Int {
  case process.receive(subject, 1000) {
    Ok(-1) -> total
    Ok(size) -> collect_sizes(subject, total + size)
    Error(_) -> total
  }
}
