//// Example for the doc of `transaction.remove_header`.

import dream/http/transaction.{type Header, Header, remove_header}

pub fn public_headers() -> List(Header) {
  let headers = [
    Header("Server", "dream"),
    Header("Content-Type", "text/plain"),
  ]
  // The name match ignores case: [Header("Content-Type", "text/plain")]
  remove_header(headers, "server")
}
