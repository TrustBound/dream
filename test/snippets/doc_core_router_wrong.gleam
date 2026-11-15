//// Example for the `dream/router` module doc: a parameter name typo that
//// the compiler does not catch. This code is wrong on purpose.

import dream/http/request.{type Request, Get, get_param}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{route, router}

// Route definition
pub fn user_router() {
  router()
  |> route(
    method: Get,
    path: "/users/:user_id",
    controller: show_user,
    middleware: [],
  )
}

// Controller (WRONG - fails at runtime)
pub fn show_user(request: Request, _context, _services) -> Response {
  // Should be "user_id"
  case get_param(request, "id") {
    // This never runs
    Ok(param) -> text_response(status.ok, "User " <> param.value)
    // Always hits this branch
    Error(message) -> text_response(status.bad_request, message)
  }
}
