//// README: Process-Based Streaming - start_stream()
////
//// Streams a response in its own process and prints each part of it.

import dream_http_client/client.{
  type Header, type StreamFailure, await_stream, host, on_stream_chunk,
  on_stream_end, on_stream_error, on_stream_start, path, port, scheme,
  start_stream, stream_failure_to_string,
}
import gleam/bit_array
import gleam/http
import gleam/io

pub fn stream_and_print() -> Result(Nil, String) {
  let stream_result =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> on_stream_start(print_stream_start)
    |> on_stream_chunk(print_chunk)
    |> on_stream_end(print_stream_end)
    |> on_stream_error(print_stream_error)
    |> start_stream()

  case stream_result {
    Error(reason) -> Error(reason)
    Ok(stream_handle) -> {
      // Wait for the stream to complete
      await_stream(stream_handle)
      Ok(Nil)
    }
  }
}

fn print_stream_start(_headers: List(Header)) -> Nil {
  io.println("Stream started")
}

fn print_chunk(data: BitArray) -> Nil {
  case bit_array.to_string(data) {
    Ok(text) -> io.print(text)
    Error(Nil) -> io.print("<binary>")
  }
}

fn print_stream_end(_headers: List(Header)) -> Nil {
  io.println("\nStream completed")
}

fn print_stream_error(failure: StreamFailure) -> Nil {
  io.println_error("Stream error: " <> stream_failure_to_string(failure))
}
