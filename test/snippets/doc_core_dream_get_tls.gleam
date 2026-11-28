//// Example for the doc of `dream.get_tls`.

import dream/dream.{type Tls, get_tls}
import dream/servers/mist/server
import gleam/option.{type Option}

pub fn plain_http_tls() -> Option(Tls) {
  // A server with no certificate and key files serves plain HTTP: None
  get_tls(server.new())
}
