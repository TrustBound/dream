//// Example for the doc of `dream.get_shutdown_timeout`.

import dream/dream.{get_shutdown_timeout}
import dream/servers/mist/server

pub fn default_shutdown_timeout() -> Int {
  // A new server waits at most 30 seconds: 30_000
  get_shutdown_timeout(server.new())
}
