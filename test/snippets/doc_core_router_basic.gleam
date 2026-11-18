//// Example for the `dream/router` module doc: basic routing.

import dream/http/request.{Get, Post}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}

pub fn create_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/users",
    controller: create_user,
    middleware: [],
  )
}

fn index(_request, _context, _services) {
  text_response(status.ok, "Index")
}

fn show_user(incoming_request, _context, _services) {
  case request.get_string_param(incoming_request, "id") {
    Ok(id) -> text_response(status.ok, "User " <> id)
    Error(message) -> text_response(status.bad_request, message)
  }
}

fn create_user(_request, _context, _services) {
  text_response(status.created, "Created")
}
