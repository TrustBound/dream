// Router using Radix Trie for O(path depth) route matching
// String-based API matching Dream's current interface

import dream/http/request.{type Method, type Request}
import dream/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pattern_parser
import radix_poc

// ============================================================================
// Types
// ============================================================================

/// A single route definition
pub type Route(context, services) {
  Route(
    method: Method,
    path: String,
    segments: List(radix_poc.Segment),
    controller: fn(Request, context, services) -> Response,
    middleware: List(
      fn(Request, context, services, fn(Request, context, services) -> Response) ->
        Response,
    ),
    streaming: Bool,
  )
}

/// Router holding routes in a radix trie
pub type Router(context, services) {
  Router(trie: radix_poc.RadixTrie(RouteHandler(context, services)))
}

/// Internal route handler that wraps controller with metadata
pub opaque type RouteHandler(context, services) {
  RouteHandler(
    controller: fn(Request, context, services) -> Response,
    middleware: List(
      fn(Request, context, services, fn(Request, context, services) -> Response) ->
        Response,
    ),
    streaming: Bool,
    segments: List(radix_poc.Segment),
  )
}

/// Parameter with raw value for wildcard access
pub type Param {
  Param(name: String, raw: String)
}

// ============================================================================
// Router Functions
// ============================================================================

/// Create an empty router
pub fn router() -> Router(context, services) {
  Router(trie: radix_poc.new())
}

/// Add a route to the router
pub fn route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_fn: fn(Request, context, services) -> Response,
  middleware middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) {
  let segments = pattern_parser.parse_pattern(path_pattern)
  let method_string = method_to_string(method_value)

  let handler =
    RouteHandler(
      controller: controller_fn,
      middleware: middleware_list,
      streaming: False,
      segments: segments,
    )

  let updated_trie =
    radix_poc.insert(router_value.trie, method_string, segments, handler)

  Router(trie: updated_trie)
}

/// Add a streaming route to the router
pub fn stream_route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_fn: fn(Request, context, services) -> Response,
  middleware middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) {
  let segments = pattern_parser.parse_pattern(path_pattern)
  let method_string = method_to_string(method_value)

  let handler =
    RouteHandler(
      controller: controller_fn,
      middleware: middleware_list,
      streaming: True,
      segments: segments,
    )

  let updated_trie =
    radix_poc.insert(router_value.trie, method_string, segments, handler)

  Router(trie: updated_trie)
}

/// Find a route that matches the request
pub fn find_route(
  router_value: Router(context, services),
  request: Request,
) -> Option(#(RouteHandler(context, services), Request)) {
  let method_string = method_to_string(request.method)
  let path_segments = split_path(request.path)

  case radix_poc.lookup(router_value.trie, method_string, path_segments) {
    Some(radix_poc.Match(handler, params)) -> {
      let updated_request = request.set_params(request, params)
      Some(#(handler, updated_request))
    }
    None -> None
  }
}

fn split_path(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(seg) { seg != "" })
}

/// Execute a route handler with its middleware chain
pub fn execute_handler(
  handler: RouteHandler(context, services),
  request: Request,
  context: context,
  services: services,
) -> Response {
  let controller_chain =
    build_controller_chain(handler.middleware, handler.controller)
  controller_chain(request, context, services)
}

/// Check if a route handler is for streaming
pub fn is_streaming(handler: RouteHandler(context, services)) -> Bool {
  handler.streaming
}

// ============================================================================
// Parameter Extraction Functions (delegate to Dream's request module)
// ============================================================================

/// Get a parameter value by name
pub fn get_param(req: Request, name: String) -> Result(String, Nil) {
  case request.get_param(req, name) {
    Ok(path_param) -> Ok(path_param.raw)
    Error(_) -> Error(Nil)
  }
}

/// Require an integer parameter
pub fn require_int(req: Request, name: String) -> Result(Int, String) {
  case request.get_int_param(req, name) {
    Ok(num) -> Ok(num)
    Error(_) -> Error("Parameter '" <> name <> "' must be an integer")
  }
}

/// Require a string parameter
pub fn require_string(req: Request, name: String) -> Result(String, String) {
  case request.get_string_param(req, name) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Missing required parameter: " <> name)
  }
}

/// Get parameter with raw value (for wildcards)
pub fn get_param_with_raw(req: Request, name: String) -> Result(Param, Nil) {
  case request.get_param(req, name) {
    Ok(path_param) -> Ok(Param(name: name, raw: path_param.raw))
    Error(_) -> Error(Nil)
  }
}

// ============================================================================
// Middleware Chain Building
// ============================================================================

/// Build a controller chain from middleware and final controller
pub fn build_controller_chain(
  middleware: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
  final_controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  let reversed = list.reverse(middleware)
  build_chain_recursive(reversed, final_controller)
}

fn build_chain_recursive(
  middleware: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  case middleware {
    [] -> controller
    [middleware_fn, ..rest] -> {
      let wrapped_controller =
        create_wrapped_controller(middleware_fn, controller)
      build_chain_recursive(rest, wrapped_controller)
    }
  }
}

fn create_wrapped_controller(
  middleware_fn: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) ->
    Response,
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  fn(request, context, services) {
    middleware_fn(request, context, services, controller)
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

fn method_to_string(method: Method) -> String {
  request.method_to_string(method)
}
