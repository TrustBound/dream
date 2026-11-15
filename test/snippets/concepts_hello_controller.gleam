//// Concepts: a controller module with two actions

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_string, text_response}
import dream/http/error
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/result

pub fn greet_world(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

pub fn greet_person(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let result = {
    use name <- result.try(require_string(request, "name"))
    Ok(name)
  }

  case result {
    Ok(name) -> text_response(status.ok, "Hello, " <> name <> "!")
    Error(err) -> text_response(error.to_status_code(err), error.message(err))
  }
}
