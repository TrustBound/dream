//// Router for matching HTTP requests to handlers
////
//// This module provides routing functionality for matching HTTP requests
//// to route handlers based on method and path patterns, including support
//// for path parameters.

import dream/core/http/statuses.{convert_client_error_to_status, not_found}
import dream/core/http/transaction.{
  type Method, type Request, type Response, Get,
}
import gleam/list
import gleam/option
import gleam/string

/// Middleware wrapper type
pub type Middleware {
  Middleware(fn(Request) -> Response)
}

/// Route definition with method, path pattern, handler, and middleware
pub type Route {
  Route(
    method: Method,
    path: String,
    handler: fn(Request) -> Response,
    middleware: List(Middleware),
  )
}

/// Router containing a list of routes
pub type Router {
  Router(routes: List(Route))
}

/// Default 404 handler
fn default_404_handler(_request: Request) -> Response {
  transaction.text_response(
    convert_client_error_to_status(not_found()),
    "Not Found",
  )
}

/// Default route constant
pub const new = Route(
  method: Get,
  path: "/",
  handler: default_404_handler,
  middleware: [],
)

/// Default router constant
pub const router = Router(routes: [])

/// Set the HTTP method for the route
pub fn method(route: Route, method_value: Method) -> Route {
  Route(..route, method: method_value)
}

/// Set the path for the route
pub fn path(route: Route, path_value: String) -> Route {
  Route(..route, path: path_value)
}

/// Set the handler function for the route
pub fn handler(route: Route, handler_function: fn(Request) -> Response) -> Route {
  Route(..route, handler: handler_function)
}

/// Add middleware to the route
pub fn add_middleware(
  route: Route,
  middleware_fn: fn(Request) -> Response,
) -> Route {
  Route(..route, middleware: [Middleware(middleware_fn), ..route.middleware])
}

/// Add a route to the router
pub fn add_route(router: Router, route: Route) -> Router {
  Router(routes: [route, ..router.routes])
}

/// Match a request path against a route pattern
/// Pattern: "/users/:id/posts/:post_id"
/// Path: "/users/123/posts/456"
/// Returns: Some([#("id", "123"), #("post_id", "456")])
pub fn match_path(
  pattern: String,
  path: String,
) -> option.Option(List(#(String, String))) {
  let pattern_segments =
    string.split(pattern, "/") |> list.filter(fn(segment) { segment != "" })
  let path_segments =
    string.split(path, "/") |> list.filter(fn(segment) { segment != "" })

  case list.length(pattern_segments) == list.length(path_segments) {
    False -> option.None
    True -> extract_params(pattern_segments, path_segments, [])
  }
}

/// Extract path parameters from pattern segments and path segments
fn extract_params(
  pattern_segments: List(String),
  path_segments: List(String),
  accumulated_params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case pattern_segments, path_segments {
    [], [] -> option.Some(list.reverse(accumulated_params))

    [pattern_seg, ..rest_pat], [path_seg, ..rest_path] ->
      match_segment(
        pattern_seg,
        path_seg,
        rest_pat,
        rest_path,
        accumulated_params,
      )

    _, _ -> option.None
  }
}

/// Match a single segment from pattern and path, handling parameter extraction
fn match_segment(
  pattern_seg: String,
  path_seg: String,
  rest_pattern: List(String),
  rest_path: List(String),
  params: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  let is_param = string.starts_with(pattern_seg, ":")
  let segments_match = pattern_seg == path_seg

  case is_param, segments_match {
    // Parameter segment - extract and continue
    True, _ -> {
      let param_name = string.drop_start(pattern_seg, 1)
      extract_params(rest_pattern, rest_path, [
        #(param_name, path_seg),
        ..params
      ])
    }
    // Static segment matches - continue
    False, True -> extract_params(rest_pattern, rest_path, params)
    // Static segment doesn't match - fail
    False, False -> option.None
  }
}

/// Find matching route and extract params
pub fn find_route(
  router: Router,
  request: Request,
) -> option.Option(#(Route, List(#(String, String)))) {
  router.routes
  |> list.find_map(fn(route) {
    let method_matches = route.method == request.method

    case method_matches {
      False -> Error(Nil)
      True ->
        case match_path(route.path, request.path) {
          option.Some(params) -> Ok(#(route, params))
          option.None -> Error(Nil)
        }
    }
  })
  |> option.from_result
}
