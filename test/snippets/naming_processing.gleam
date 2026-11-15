//// Naming conventions: Request and Response Processing
////
//// `handle_{noun}` does the work for a request, `route_{noun}` sends a
//// request to its controller, and `match_{noun}` compares a value with a
//// pattern.

import dream/dream
import dream/http.{type Request, type Response}
import dream/http/error.{type Error, Unauthorized, message, to_status_code}
import dream/http/request.{type Method, Get}
import dream/router
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn handle_request(request: Request) -> Response {
  case handle_authentication(request) {
    Ok(_request) -> http.text_response(http.ok, "Welcome")
    Error(error) -> handle_error(error)
  }
}

pub fn handle_error(error: Error) -> Response {
  http.text_response(to_status_code(error), message(error))
}

pub fn handle_authentication(request: Request) -> Result(Request, Error) {
  case http.get_header(request.headers, "Authorization") {
    Some(_token) -> Ok(request)
    None -> Error(Unauthorized("Missing Authorization header"))
  }
}

pub fn respond(request: Request) -> Response {
  let app_router =
    router.router()
    |> router.route(method: Get, path: "/", controller: home, middleware: [])
  dream.route_request(app_router, request, Nil, Nil)
}

pub fn match_method(allowed: List(Method), method: Method) -> Bool {
  list.contains(allowed, method)
}

pub fn match_path(pattern: String, path: String) -> Bool {
  let pattern_segments = string.split(pattern, "/")
  let path_segments = string.split(path, "/")
  list.length(pattern_segments) == list.length(path_segments)
  && list.all(list.zip(pattern_segments, path_segments), match_segment)
}

fn match_segment(segments: #(String, String)) -> Bool {
  let #(pattern_segment, path_segment) = segments
  string.starts_with(pattern_segment, ":") || pattern_segment == path_segment
}

fn home(_request, _context, _services) {
  http.text_response(http.ok, "Home")
}
