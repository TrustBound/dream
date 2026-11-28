//// Example for the docs of `params.require_form` and `params.require_field`.

import dream/http/error.{type Error}
import dream/http/params
import dream/http/request.{type Request}
import gleam/result

pub fn task_title(request: Request) -> Result(String, Error) {
  use form <- result.try(params.require_form(request))
  use title <- result.try(params.require_field(form, "title"))
  Ok(title)
}
