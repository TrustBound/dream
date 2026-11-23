//// Example for the doc of `request.parse_method`.

import dream/http/request.{type Method, parse_method}
import gleam/option.{type Option}

pub fn delete_method() -> Option(Method) {
  // The match ignores case: Some(Delete)
  parse_method("delete")
}
