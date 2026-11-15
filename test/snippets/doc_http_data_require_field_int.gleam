//// Example for the doc of `params.require_field_int`.

import dream/http/error.{type Error}
import dream/http/params
import dream/http/request.{type Request}
import gleam/result

pub fn task_priority(request: Request) -> Result(Int, Error) {
  use form <- result.try(params.require_form(request))
  use priority <- result.try(params.require_field_int(form, "priority"))
  Ok(priority)
}
