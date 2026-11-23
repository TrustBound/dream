//// Example for the doc of `dream.execute_route`.

import dream/dream.{execute_route}
import dream/http/request.{type Request, Get, get_param}
import dream/http/response.{type Response, text_response}
import dream/http/status.{bad_request, not_found, ok}
import dream/router.{find_route, route, router}
import gleam/option.{None, Some}

fn show_user(request: Request, _context, _services) -> Response {
  case get_param(request, "id") {
    Ok(param) -> text_response(ok, "User " <> param.value)
    Error(message) -> text_response(bad_request, message)
  }
}

pub fn handle(request: Request) -> Response {
  let app_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: show_user,
      middleware: [],
    )
  case find_route(app_router, request) {
    // execute_route sets the params, then runs the middleware and the
    // controller: GET /users/7 gives "User 7"
    Some(#(matched_route, params)) ->
      execute_route(matched_route, request, params, Nil, Nil)
    None -> text_response(not_found, "Route not found")
  }
}
