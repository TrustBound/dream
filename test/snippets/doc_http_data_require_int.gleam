//// Example for the doc of `params.require_int`.

import dream/http/error.{type Error}
import dream/http/params
import dream/http/request.{type Request}
import gleam/int
import gleam/result

pub fn user_path(request: Request) -> Result(String, Error) {
  // Using with gleam/result pipeline
  use id <- result.try(params.require_int(request, "id"))
  // ... rest of logic with id : Int
  Ok("/users/" <> int.to_string(id))
}
