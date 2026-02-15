//// Config mode snippet (prefix + any method) from README.

import dream_mock_server/config.{MockRoute, Prefix}
import dream_mock_server/server
import gleam/erlang/process
import gleam/int
import gleam/option
import snippets/http_helper

pub fn run() -> Result(Bool, String) {
  let port = 19_921
  let config = [
    MockRoute(
      path: "/v1/chat/completions",
      path_match: Prefix,
      method: option.None,
      status: 200,
      body: "{\"choices\":[{\"message\":{\"content\":\"\"}}]}",
    ),
  ]

  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let url = "http://localhost:" <> int.to_string(port) <> "/v1/chat/completions"
  let result = http_helper.get(url)

  server.stop(handle)
  process.sleep(200)

  case result {
    Ok(#(200, body)) ->
      Ok(body == "{\"choices\":[{\"message\":{\"content\":\"\"}}]}")
    Ok(_) -> Error("Unexpected status")
    Error(e) -> Error(e)
  }
}
