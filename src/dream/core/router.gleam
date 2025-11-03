//// Router for matching HTTP requests to handlers
////
//// This module provides routing functionality for matching HTTP requests
//// to route handlers based on method and path patterns, including support
//// for path parameters.

import dream/core/context.{type AppContext}
import dream/core/http/statuses.{convert_client_error_to_status, not_found}
import dream/core/http/transaction.{
  type Method, type Request, type Response, Get,
}
import gleam/list
import gleam/option
import gleam/string

/// Middleware wrapper type
/// Generic over context and services types
pub type Middleware(context, services) {
  Middleware(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  )
}

/// Route definition with method, path pattern, handler, and middleware
pub type Route(context, services) {
  Route(
    method: Method,
    path: String,
    handler: fn(Request, context, services) -> Response,
    middleware: List(Middleware(context, services)),
  )
}

/// Router containing a list of routes
pub type Router(context, services) {
  Router(routes: List(Route(context, services)))
}

/// Empty services type for default router
pub type EmptyServices {
  EmptyServices
}

/// Default 404 handler for AppContext
fn default_404_handler_app_context(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  transaction.text_response(
    convert_client_error_to_status(not_found()),
    "Not Found",
  )
}

/// Default route constant with AppContext
pub const new = Route(
  method: Get,
  path: "/",
  handler: default_404_handler_app_context,
  middleware: [],
)

/// Default router constant with AppContext
pub const router = Router(routes: [])

/// Set the HTTP method for the route
pub fn method(
  route: Route(context, services),
  method_value: Method,
) -> Route(context, services) {
  Route(..route, method: method_value)
}

/// Set the path for the route
pub fn path(
  route: Route(context, services),
  path_value: String,
) -> Route(context, services) {
  Route(..route, path: path_value)
}

/// Set the handler function for the route
pub fn handler(
  route: Route(context, services),
  handler_function: fn(Request, context, services) -> Response,
) -> Route(context, services) {
  Route(..route, handler: handler_function)
}

/// Add middleware to the route (accepts a list for convenience)
pub fn middleware(
  route: Route(context, services),
  middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Route(context, services) {
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  Route(..route, middleware: list.append(middleware_wrappers, route.middleware))
}

fn wrap_middleware(
  mw: fn(Request, context, services, fn(Request, context, services) -> Response) ->
    Response,
) -> Middleware(context, services) {
  Middleware(mw)
}

/// Add a route to the router
pub fn route(
  router: Router(context, services),
  method method_value: Method,
  path path_value: String,
  handler handler_function: fn(Request, context, services) -> Response,
  middleware middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) {
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  let route =
    Route(
      method: method_value,
      path: path_value,
      handler: handler_function,
      middleware: middleware_wrappers,
    )
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
    string.split(pattern, "/") |> list.filter(non_empty_segment)
  let path_segments = string.split(path, "/") |> list.filter(non_empty_segment)

  case list.length(pattern_segments) == list.length(path_segments) {
    False -> option.None
    True -> extract_params(pattern_segments, path_segments, [])
  }
}

fn non_empty_segment(segment: String) -> Bool {
  segment != ""
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
  router: Router(context, services),
  request: Request,
) -> option.Option(#(Route(context, services), List(#(String, String)))) {
  find_route_recursive(router.routes, request)
}

fn find_route_recursive(
  routes: List(Route(context, services)),
  request: Request,
) -> option.Option(#(Route(context, services), List(#(String, String)))) {
  case routes {
    [] -> option.None
    [route, ..rest] -> {
      case check_route_match(request, route) {
        Ok(result) -> option.Some(result)
        Error(_) -> find_route_recursive(rest, request)
      }
    }
  }
}

fn check_route_match(
  request: Request,
  route: Route(context, services),
) -> Result(#(Route(context, services), List(#(String, String))), Nil) {
  let method_matches = route.method == request.method

  case method_matches {
    False -> Error(Nil)
    True -> check_path_match(route, request.path)
  }
}

fn check_path_match(
  route: Route(context, services),
  path: String,
) -> Result(#(Route(context, services), List(#(String, String))), Nil) {
  case match_path(route.path, path) {
    option.Some(params) -> Ok(#(route, params))
    option.None -> Error(Nil)
  }
}

/// Build a handler chain from middleware and final handler
/// Middleware are executed in order: first middleware wraps second, wraps third, etc.
pub fn build_handler_chain(
  middleware: List(Middleware(context, services)),
  final_handler: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  // Reverse middleware list so first added wraps outermost
  let reversed = list.reverse(middleware)
  build_chain_recursive(reversed, final_handler)
}

fn build_chain_recursive(
  middleware: List(Middleware(context, services)),
  handler: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  case middleware {
    [] -> handler
    [mw, ..rest] -> {
      case mw {
        Middleware(middleware_fn) -> {
          let wrapped_handler = create_wrapped_handler(middleware_fn, handler)
          build_chain_recursive(rest, wrapped_handler)
        }
      }
    }
  }
}

fn create_wrapped_handler(
  middleware_fn: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) ->
    Response,
  handler: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  fn(request, context, services) {
    middleware_fn(request, context, services, handler)
  }
}
