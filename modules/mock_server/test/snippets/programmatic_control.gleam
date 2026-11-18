//// README: Programmatic Control

import dream/servers/mist/server as dream_server
import dream_mock_server/server
import gleam/int
import gleam/result
import gleam/string
import snippets/http_helper

pub fn fetch_text(port: Int) -> Result(#(Int, String), String) {
  // Start server
  use handle <- result.try(start_server(port))

  // Use server
  let response =
    http_helper.get("http://localhost:" <> int.to_string(port) <> "/text")

  // Stop server
  server.stop(handle)
  response
}

fn start_server(port: Int) -> Result(dream_server.ServerHandle, String) {
  server.start(port)
  |> result.map_error(string.inspect)
}
