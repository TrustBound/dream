//// Lesson 2: reading a path parameter with require_int

import dream/http.{type Request, type Response, ok, require_int, text_response}
import dream/http/error
import gleam/int
import gleam/result

pub fn show(
  request: Request,
  _context: context,
  _services: services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    Ok("User " <> int.to_string(id))
  }

  case result {
    Ok(body) -> text_response(ok, body)
    Error(err) -> text_response(error.to_status_code(err), error.message(err))
  }
}
