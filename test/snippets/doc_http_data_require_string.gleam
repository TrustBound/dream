//// Example for the doc of `params.require_string`.

import dream/http/error.{type Error}
import dream/http/params
import dream/http/request.{type Request}
import gleam/result

pub fn greeting(request: Request) -> Result(String, Error) {
  use name <- result.try(params.require_string(request, "name"))
  // ... rest of logic with name : String
  Ok("Hello, " <> name)
}
