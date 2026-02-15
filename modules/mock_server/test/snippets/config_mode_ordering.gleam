//// Ordering gotcha snippet from README.

import dream_mock_server/config.{Exact, MockRoute, Prefix}
import dream_mock_server/server
import gleam/erlang/process
import gleam/int
import gleam/option
import snippets/http_helper

pub fn run() -> Result(Bool, String) {
  let port = 19_923
  let config = [
    MockRoute("/api/special", Exact, option.None, 200, "special"),
    MockRoute("/api", Prefix, option.None, 200, "general"),
  ]

  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let base = "http://localhost:" <> int.to_string(port)
  let special = http_helper.get(base <> "/api/special")
  let general = http_helper.get(base <> "/api/other")

  server.stop(handle)
  process.sleep(200)

  case special, general {
    Ok(#(200, "special")), Ok(#(200, "general")) -> Ok(True)
    _, _ -> Error("Route ordering did not produce expected matches")
  }
}
