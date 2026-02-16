//// Programmatic mode snippet from README.

import dream_mock_server/server
import gleam/erlang/process
import gleam/int
import snippets/http_helper

pub fn run() -> Result(Bool, String) {
  let port = 19_920
  let assert Ok(handle) = server.start(port)
  process.sleep(200)

  let url = "http://localhost:" <> int.to_string(port) <> "/text"
  let result = http_helper.get(url)

  server.stop(handle)
  process.sleep(200)

  case result {
    Ok(#(200, body)) -> Ok(body != "")
    Ok(_) -> Error("Unexpected status")
    Error(e) -> Error(e)
  }
}
