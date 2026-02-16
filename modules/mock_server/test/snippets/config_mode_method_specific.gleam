//// Exact + method-specific snippet from README.

import dream/http/request.{Get, Post}
import dream_mock_server/config.{Exact, MockRoute}
import dream_mock_server/server
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import snippets/http_helper

pub fn run() -> Result(Bool, String) {
  let port = 19_922
  let config = [
    MockRoute("/resource", Exact, Some(Get), 200, "{\"ok\":true}"),
    MockRoute("/resource", Exact, Some(Post), 201, "{\"created\":true}"),
  ]

  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let url = "http://localhost:" <> int.to_string(port) <> "/resource"
  let get_result = http_helper.get(url)
  let post_result = http_helper.post(url, "")

  server.stop(handle)
  process.sleep(200)

  case get_result, post_result {
    Ok(#(200, "{\"ok\":true}")), Ok(#(201, "{\"created\":true}")) -> Ok(True)
    _, _ -> Error("Method-specific routing did not match expected responses")
  }
}
