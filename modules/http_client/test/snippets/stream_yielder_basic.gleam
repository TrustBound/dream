//// Yielder-Based Streaming
////
//// Example snippet showing basic yielder streaming.
////
//// Note: README shows api.openai.com, but tests use localhost:9876/stream/fast

import dream_http_client/client.{host, path, port, scheme, stream_yielder}
import gleam/bytes_tree
import gleam/http
import gleam/int
import gleam/yielder

pub fn stream_and_process() -> Result(String, String) {
  let total_bytes =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")
    |> stream_yielder()
    |> yielder.fold(0, fn(total, chunk_result) {
      case chunk_result {
        Ok(chunk) -> {
          let size = bytes_tree.byte_size(chunk)
          total + size
        }
        Error(_) -> total
      }
    })

  case total_bytes > 0 {
    True -> Ok("Received " <> int.to_string(total_bytes) <> " bytes")
    False -> Error("No bytes received")
  }
}
