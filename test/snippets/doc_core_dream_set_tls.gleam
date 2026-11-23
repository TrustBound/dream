//// Example for the doc of `dream.set_tls`.

import dream/dream.{type Tls, Tls, get_tls, set_tls}
import dream/servers/mist/server
import gleam/option.{type Option, Some}

pub fn tls_files() -> Option(Tls) {
  let app =
    server.new()
    |> set_tls(Some(Tls(certfile: "cert.pem", keyfile: "key.pem")))
  // Some(Tls(certfile: "cert.pem", keyfile: "key.pem"))
  get_tls(app)
}
