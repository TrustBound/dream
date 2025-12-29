//// Stream Cancellation
////
//// Example showing how to cancel a running stream using the StreamHandle.
////
//// Note: Uses localhost:9876 (dream_mock_server).

import dream_http_client/client.{
  cancel_stream_handle, host, is_stream_active, path, port, scheme, start_stream,
}
import gleam/erlang/process
import gleam/http
import gleam/result

pub fn cancel_stream() -> Result(Bool, String) {
  let request =
    client.new()
    |> scheme(http.Http)
    |> host("localhost")
    |> port(9876)
    |> path("/stream/fast")

  use handle <- result.try(start_stream(request))

  // Cancel quickly while it's likely still running. If it finished already,
  // cancellation is still safe and should not error.
  let _ = process.sleep(10)
  let _was_active = is_stream_active(handle)
  cancel_stream_handle(handle)

  // Cancellation is async; wait briefly for the process to exit.
  case wait_until_stopped(handle, 30) {
    True -> Ok(True)
    False -> Error("Expected stream process to stop after cancellation")
  }
}

fn wait_until_stopped(handle: client.StreamHandle, attempts_left: Int) -> Bool {
  case attempts_left <= 0 {
    True -> False
    False -> {
      case client.is_stream_active(handle) {
        False -> True
        True -> {
          let _ = process.sleep(50)
          wait_until_stopped(handle, attempts_left - 1)
        }
      }
    }
  }
}
