//// Route configuration and request matching
////
//// The router matches incoming requests to controllers based on HTTP method and path patterns.
//// It uses a radix trie for O(path depth) lookup performance, making it efficient even with
//// hundreds of routes. The router supports path parameters, wildcards, middleware chains,
//// and custom context/services types.
////
//// ## Basic Routing
////
//// ```gleam
//// import dream/router.{route, router}
//// import dream/http/request.{Get, Post}
////
//// pub fn create_router() {
////   router()
////   |> route(method: Get, path: "/", controller: controllers.index, middleware: [])
////   |> route(method: Get, path: "/users/:id", controller: controllers.show_user, middleware: [])
////   |> route(method: Post, path: "/users", controller: controllers.create_user, middleware: [])
//// }
//// ```
////
//// ## Path Parameters
////
//// Use `:name` to capture path segments as parameters:
//// - `/users/:id` matches `/users/123` and extracts `id = "123"`
//// - `/posts/:post_id/comments/:id` extracts both parameters
////
//// Access parameters in your controller with `request.get_param(request, "id")`.
////
//// ### Parameter Name Remapping
////
//// Routes with different parameter names at the same position are supported.
//// Each route extracts parameters using its own declared parameter names:
////
//// ```gleam
//// router()
//// |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
//// |> route(method: Get, path: "/users/:user_id/posts", controller: show_posts, middleware: [])
//// ```
////
//// - `/users/123` extracts `id = "123"` (first route's param name)
//// - `/users/123/posts` extracts `user_id = "123"` (second route's param name)
////
//// The router automatically remaps parameters to match each route's declared names,
//// even when routes share parameter positions in the trie structure.
////
//// ## Wildcards
////
//// Wildcards match one or more path segments:
//// - `*` or `*name` - Matches exactly one segment
//// - `**` or `**path` - Matches zero or more segments (greedy)
//// - `*.jpg` - Matches any path ending in `.jpg`
//// - `*.{jpg,png,gif}` - Matches multiple extensions
////
//// ## Middleware
////
//// Middleware run before (and optionally after) your controller:
////
//// ```gleam
//// router()
//// |> route(
////   method: Get,
////   path: "/admin/users",
////   controller: controllers.admin_users,
////   middleware: [auth_middleware, logging_middleware]
//// )
//// ```
////
//// Middleware are executed in order: `auth` → `logging` → controller → `logging` → `auth`.
//// Each middleware can modify the request on the way in or the response on the way out.
////
//// ## Route Matching Priority
////
//// When multiple routes could match, the most specific wins:
//// 1. Literal segments (exact match) - highest priority
//// 2. Parameters (`:id`)
//// 3. Single wildcards (`*`)
//// 4. Extension patterns (`*.jpg`)
//// 5. Multi-segment wildcards (`**`) - lowest priority
////
//// This means `/users/new` will match before `/users/:id` even if defined in reverse order.
////
//// ## Important: Parameter Validation Trade-off
////
//// Dream validates path parameters at runtime, not compile-time. This means:
////
//// - ✅ Ergonomic API: Simple, clean route definitions
//// - ✅ Flexible: Easy to add/change routes dynamically
//// - ❌ No compile-time safety: Typos in parameter names cause runtime errors
////
//// Example of what the compiler WON'T catch:
////
//// ```gleam
//// // Route definition
//// router()
//// |> route(method: Get, path: "/users/:user_id", controller: show_user, middleware: [])
////
//// // Controller (WRONG - will fail at runtime)
//// fn show_user(request: Request, context: Context, services: Services) -> Response {
////   case get_param(request, "id") {  // Should be "user_id"
////     Ok(param) -> // This will never execute
////     Error(_) -> // Always hits this branch
////   }
//// }
//// ```
////
//// This is an intentional design decision favoring ergonomics over compile-time guarantees.
//// We're exploring more type-safe alternatives that maintain clean APIs in
//// [GitHub Discussion #15](https://github.com/TrustBound/dream/discussions/15).
////
//// **Mitigation:** Write integration tests that exercise your routes. The runtime
//// validators (`get_param`, `get_int_param`, etc.) will catch mismatches immediately.

import dream/http/request.{type Method, type Request}
import dream/http/response.{type Response}
import dream/router/parser
import dream/router/trie.{type Segment} as trie_module
import gleam/list
import gleam/option
import gleam/string

// ============================================================================
// Public Types
// ============================================================================

/// Middleware function wrapper
///
/// Middleware intercept requests before they reach controllers and responses before
/// they're sent back. They're generic over context and services types so they can
/// work with any application configuration.
pub type Middleware(context, services) {
  Middleware(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  )
}

/// A single route definition
///
/// Combines an HTTP method, path pattern, controller function, and optional middleware.
/// This type is public for compatibility but most applications won't use it directly.
pub type Route(context, services) {
  Route(
    method: Method,
    path: String,
    controller: fn(Request, context, services) -> Response,
    middleware: List(Middleware(context, services)),
    streaming: Bool,
  )
}

/// Router holding your application's routes
///
/// The router uses a radix trie for efficient O(path depth) route matching,
/// making it performant even with hundreds of routes. It's generic over context
/// and services types so the type system can verify your whole app.
pub opaque type Router(context, services) {
  Router(trie: trie_module.RadixTrie(RouteHandler(context, services)))
}

/// Internal route handler stored in the trie
///
/// Wraps the controller and metadata needed to execute a matched route.
/// Stores param names in path order to allow remapping params after lookup.
type RouteHandler(context, services) {
  RouteHandler(
    controller: fn(Request, context, services) -> Response,
    middleware: List(Middleware(context, services)),
    streaming: Bool,
    /// Param names in path order (e.g., ["id", "post_id"] for /users/:id/posts/:post_id)
    /// Used to remap params extracted during trie traversal to match route's param names
    param_names: List(String),
  )
}

/// Placeholder for when you haven't defined services yet
///
/// Use this as your services type during initial development. Replace it with your
/// own services type when you add database connections, caches, or other shared dependencies.
pub type EmptyServices {
  EmptyServices
}

// ============================================================================
// Router Construction
// ============================================================================

/// Empty router with no routes
///
/// Starting point for building your application's router. Chain this with
/// `route()` or `stream_route()` calls to add routes.
///
/// ## Example
///
/// ```gleam
/// router()
/// |> route(method: Get, path: "/", controller: home, middleware: [])
/// |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
/// ```
pub fn router() -> Router(context, services) {
  Router(trie: trie_module.new())
}

/// Add a route to the router
///
/// Registers a route with the given method, path pattern, controller, and middleware.
/// The path supports parameters (`:id`), wildcards (`*`, `**`), and extensions (`*.jpg`).
///
/// Routes are stored in a radix trie, so they don't need to be defined in any particular
/// order - the most specific route will always match first.
///
/// ## Examples
///
/// ```gleam
/// // Simple route
/// route(router, method: Get, path: "/", controller: home_controller, middleware: [])
///
/// // Route with path parameter
/// route(router, method: Get, path: "/users/:id", controller: show_user, middleware: [])
///
/// // Route with middleware
/// route(router, method: Post, path: "/admin/users", controller: create_user, middleware: [auth, logging])
///
/// // Wildcard route for static files
/// route(router, method: Get, path: "/assets/**path", controller: serve_static, middleware: [])
/// ```
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
  let segments = parser.parse_pattern(path_pattern)
  let method_string = method_to_string(method_value)
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  let param_names = extract_param_names_from_segments(segments)

  let handler =
    RouteHandler(
      controller: controller_fn,
      middleware: middleware_wrappers,
      streaming: False,
      param_names: param_names,
    )

  let updated_trie =
    trie_module.insert(router_value.trie, method_string, segments, handler)

  Router(trie: updated_trie)
}

/// Add a streaming route to the router
///
/// Registers a route that receives the request body as a stream (Yielder(BitArray))
/// instead of a buffered string. Use this for large file uploads, proxying external
/// APIs, or any request body > 10MB.
///
/// The controller receives `request.stream` as `Some(Yielder(BitArray))` and
/// `request.body` as an empty string. Process chunks as they arrive without
/// buffering the entire body in memory.
///
/// ## Example
///
/// ```gleam
/// router
/// |> stream_route(method: Post, path: "/upload", controller: handle_upload, middleware: [auth])
/// |> stream_route(method: Put, path: "/files/:id", controller: replace_file, middleware: [])
/// ```
///
/// ## When to Use
///
/// - File uploads > 10MB
/// - Proxying external APIs
/// - Video/audio streaming
/// - Large form submissions
///
/// For regular requests (JSON APIs, forms < 10MB), use `route()` instead.
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
  let segments = parser.parse_pattern(path_pattern)
  let method_string = method_to_string(method_value)
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  let param_names = extract_param_names_from_segments(segments)

  let handler =
    RouteHandler(
      controller: controller_fn,
      middleware: middleware_wrappers,
      streaming: True,
      param_names: param_names,
    )

  let updated_trie =
    trie_module.insert(router_value.trie, method_string, segments, handler)

  Router(trie: updated_trie)
}

// ============================================================================
// Route Matching
// ============================================================================

/// Find the route matching the request
///
/// Searches the router's trie for a route that matches the request's method and path.
/// Returns the matched route and extracted path parameters, or None if no route matches.
///
/// Uses radix trie lookup for O(path depth) performance, independent of total routes.
///
/// ## Parameters
///
/// - `router_value`: Router with configured routes
/// - `request`: HTTP request to match against
///
/// ## Returns
///
/// - `Some(#(route, params))`: Matched route and extracted path parameters
/// - `None`: No matching route found
///
/// ## Example
///
/// ```gleam
/// let app_router = router
///   |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
///
/// case find_route(app_router, request) {
///   Some(#(route, params)) -> {
///     // route.controller is show_user
///     // params is [#("id", "123")] if path was "/users/123"
///   }
///   None -> // No route matched
/// }
/// ```
pub fn find_route(
  router_value: Router(context, services),
  request: Request,
) -> option.Option(#(Route(context, services), List(#(String, String)))) {
  let method_string = method_to_string(request.method)
  let path_segments = split_path(request.path)

  case trie_module.lookup(router_value.trie, method_string, path_segments) {
    option.Some(trie_module.Match(handler, params)) -> {
      // Remap params using the route's param_names
      // Params are accumulated in reverse order during traversal, so reverse them first
      // to get path order, remap, then reverse back to maintain backward compatibility
      let reversed_params = list.reverse(params)
      let remapped_params =
        remap_params_to_route_names(reversed_params, handler.param_names)
      // Reverse back to maintain backward compatibility (last param first)
      let final_params = list.reverse(remapped_params)

      let route =
        Route(
          method: request.method,
          path: request.path,
          controller: handler.controller,
          middleware: handler.middleware,
          streaming: handler.streaming,
        )
      option.Some(#(route, final_params))
    }
    option.None -> option.None
  }
}

/// Split a path into segments for trie lookup
fn split_path(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(is_non_empty_segment)
}

/// Check if a segment is non-empty
fn is_non_empty_segment(seg: String) -> Bool {
  seg != ""
}

/// Extract param names from segments in path order
///
/// Extracts names from Param, SingleWildcard, and MultiWildcard segments.
/// Used to store param names with the route handler for remapping after lookup.
fn extract_param_names_from_segments(segments: List(Segment)) -> List(String) {
  case segments {
    [] -> []
    [segment, ..rest] -> {
      let rest_names = extract_param_names_from_segments(rest)
      let name = extract_param_name_from_segment(segment)
      case name {
        option.Some(n) -> [n, ..rest_names]
        option.None -> rest_names
      }
    }
  }
}

/// Extract param name from a single segment
fn extract_param_name_from_segment(segment: Segment) -> option.Option(String) {
  case segment {
    trie_module.Param(name) -> option.Some(name)
    trie_module.SingleWildcard(option.Some(name)) -> option.Some(name)
    trie_module.MultiWildcard(option.Some(name)) -> option.Some(name)
    trie_module.SingleWildcard(option.None) -> option.Some("wildcard")
    trie_module.MultiWildcard(option.None) -> option.Some("path")
    trie_module.ExtensionPattern(_) -> option.None
    trie_module.Literal(_) -> option.None
  }
}

/// Remap params extracted during trie traversal to match route's param names
///
/// Params are extracted using the trie node's param names (which may differ
/// from the route's param names when routes share param positions). This function
/// remaps them to the correct names based on the matched route's param_names.
///
/// Both lists should be in path order (first param first).
fn remap_params_to_route_names(
  extracted_params: List(#(String, String)),
  route_param_names: List(String),
) -> List(#(String, String)) {
  case extracted_params, route_param_names {
    [], _ -> []
    _, [] -> extracted_params
    [#(_old_name, value), ..rest_params], [new_name, ..rest_names] -> {
      let remapped_rest = remap_params_to_route_names(rest_params, rest_names)
      [#(new_name, value), ..remapped_rest]
    }
  }
}

// ============================================================================
// Middleware Chain Building
// ============================================================================

/// Build a controller chain from middleware and final controller
///
/// Composes middleware with the controller to create a single function. Middleware
/// execute in order on the way in, then in reverse order on the way out.
///
/// For middleware `[auth, logging]` with controller `handle`:
/// Request → auth → logging → handle → logging → auth → Response
///
/// ## Parameters
///
/// - `middleware`: List of middleware to apply
/// - `final_controller`: The controller that handles the request
///
/// ## Returns
///
/// A composed function that applies all middleware and the controller
pub fn build_controller_chain(
  middleware: List(Middleware(context, services)),
  final_controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  // Reverse middleware list so first added wraps outermost
  let reversed = list.reverse(middleware)
  build_chain_recursive(reversed, final_controller)
}

/// Recursively build the middleware chain
fn build_chain_recursive(
  middleware: List(Middleware(context, services)),
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  case middleware {
    [] -> controller
    [mw, ..rest] -> {
      case mw {
        Middleware(middleware_fn) -> {
          let wrapped_controller =
            create_wrapped_controller(middleware_fn, controller)
          build_chain_recursive(rest, wrapped_controller)
        }
      }
    }
  }
}

/// Wrap a controller with a middleware function
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
  wrap_controller_with_middleware(middleware_fn, controller)
}

/// Create a wrapped controller that applies middleware
///
/// This is a named function to avoid anonymous functions in production code.
fn wrap_controller_with_middleware(
  middleware_fn: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) ->
    Response,
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  apply_middleware_to_controller(middleware_fn, controller)
}

/// Apply middleware to a controller, creating a wrapped controller function
fn apply_middleware_to_controller(
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

/// Wrap a middleware function in the Middleware type
fn wrap_middleware(
  mw: fn(Request, context, services, fn(Request, context, services) -> Response) ->
    Response,
) -> Middleware(context, services) {
  Middleware(mw)
}

/// Convert an HTTP method to its string representation
fn method_to_string(method: Method) -> String {
  request.method_to_string(method)
}
