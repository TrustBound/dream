//// Example for the doc of `transaction.parse_method`.

import dream/http/transaction.{type Method, parse_method}
import gleam/option.{type Option}

pub fn delete_method() -> Option(Method) {
  // The match ignores case: Some(Delete)
  parse_method("delete")
}
