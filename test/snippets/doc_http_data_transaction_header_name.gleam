//// Example for the doc of `transaction.header_name`.

import dream/http/transaction.{Header, header_name}

pub fn content_type_name() -> String {
  let header = Header("Content-Type", "text/html")
  // "Content-Type"
  header_name(header)
}
