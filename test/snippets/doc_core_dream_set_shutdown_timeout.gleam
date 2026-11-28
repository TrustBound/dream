//// Example for the doc of `dream.set_shutdown_timeout`.

import dream/dream.{get_shutdown_timeout, set_shutdown_timeout}
import dream/servers/mist/server

pub fn ten_seconds() -> Int {
  let app =
    server.new()
    |> set_shutdown_timeout(10_000)
  // 10_000
  get_shutdown_timeout(app)
}
