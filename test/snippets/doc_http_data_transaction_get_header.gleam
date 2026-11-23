//// Example for the doc of `transaction.get_header`.

import dream/http/transaction.{Header, get_header}
import gleam/option.{type Option}

pub fn content_type() -> Option(String) {
  let headers = [Header("Content-Type", "application/json")]
  // The name match ignores case: Some("application/json")
  get_header(headers, "content-type")
}
