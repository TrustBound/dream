//// Example for the doc of `transaction.header_value`.

import dream/http/transaction.{Header, header_value}

pub fn content_type_value() -> String {
  let header = Header("Content-Type", "text/html")
  // "text/html"
  header_value(header)
}
