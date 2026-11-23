//// Example for the doc of `request.get_query_param`.

import dream/http/request.{get_query_param}
import gleam/option.{type Option}

pub fn search_term() -> Option(String) {
  let query = "q=hello%20world&page=2"
  // The value is decoded: Some("hello world")
  get_query_param(query, "q")
}
