//// README: Config mode
////
//// One prefix route for any method, started in config mode.

import dream/servers/mist/server as dream_server
import dream_mock_server/config.{type MockRoute, MockRoute, Prefix}
import dream_mock_server/server
import gleam/option.{None}
import gleam/otp/actor

/// One route: path /v1/chat/completions (prefix match), any method, 200 + JSON body
pub fn chat_completion_routes() -> List(MockRoute) {
  [
    MockRoute(
      path: "/v1/chat/completions",
      path_match: Prefix,
      method: None,
      status: 200,
      body: "{\"choices\":[{\"message\":{\"content\":\"\"}}]}",
    ),
  ]
}

pub fn start_chat_mock(
  port: Int,
) -> Result(dream_server.ServerHandle, actor.StartError) {
  // Point your proxy or client at http://localhost:<port>,
  // then call server.stop(handle).
  server.start_with_config(port, chat_completion_routes())
}
