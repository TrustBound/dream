//// Message-Based Streaming with Callbacks
////
//// Example showing how to handle HTTP streaming with the callback-based API.
//// This demonstrates processing chunks as they arrive in a dedicated process.

import dream_http_client/client
import gleam/bit_array
import gleam/http
import gleam/io

pub fn stream_and_print() -> Result(Nil, String) {
  // Start the stream with callbacks
  let stream_result =
    client.new
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(9876)
    |> client.path("/stream/fast")
    |> client.on_stream_start(fn(_headers) { io.println("Stream started") })
    |> client.on_stream_chunk(fn(data) {
      case bit_array.to_string(data) {
        Ok(text) -> io.print(text)
        Error(_) -> io.print("<binary>")
      }
    })
    |> client.on_stream_end(fn(_headers) { io.println("\nStream completed") })
    |> client.on_stream_error(fn(reason) {
      io.println_error("Stream error: " <> reason)
    })
    |> client.start_stream()

  case stream_result {
    Error(reason) -> Error(reason)
    Ok(stream_handle) -> {
      // Wait for stream to complete
      client.await_stream(stream_handle)
      Ok(Nil)
    }
  }
}
