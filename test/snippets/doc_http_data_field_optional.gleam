//// Example for the doc of `params.field_optional`.

import dream/http/params
import gleam/option.{type Option}

pub fn task_description(form: List(#(String, String))) -> Option(String) {
  let description = params.field_optional(form, "description")
  description
}
