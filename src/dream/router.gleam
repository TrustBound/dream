//// Route configuration and request matching
////
//// Guide: [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
////
//// The router matches incoming requests to controllers based on HTTP method and path patterns.
//// It uses a radix trie for O(path depth) lookup performance, making it efficient even with
//// hundreds of routes. The router supports path parameters, wildcards, middleware chains,
//// and custom context/services types.
////
//// ## Basic Routing
////
//// ### Basic routing <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router_basic.gleam#L3-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/request.{Get, Post}
//// import dream/http/response.{text_response}
//// import dream/http/status
//// import dream/router.{route, router}
////
//// pub fn create_router() {
////   router()
////   |> route(method: Get, path: "/", controller: index, middleware: [])
////   |> route(
////     method: Get,
////     path: "/users/:id",
////     controller: show_user,
////     middleware: [],
////   )
////   |> route(
////     method: Post,
////     path: "/users",
////     controller: create_user,
////     middleware: [],
////   )
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
//// ### Different parameter names <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L10-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn parameter_router() {
////   router()
////   |> route(
////     method: Get,
////     path: "/users/:id",
////     controller: show_user,
////     middleware: [],
////   )
////   |> route(
////     method: Get,
////     path: "/users/:user_id/posts",
////     controller: show_posts,
////     middleware: [],
////   )
//// }
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
//// Wildcards match path segments:
//// - `*` or `*name` - Matches exactly one segment
//// - `**` or `**path` - Matches zero or more segments (greedy)
//// - `*.jpg` - Matches any path ending in `.jpg`
//// - `*.{jpg,png,gif}` - Matches multiple extensions
////
//// ## Middleware
////
//// Middleware run before (and optionally after) your controller:
////
//// ### Add middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L26-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// pub fn admin_router() {
////   router()
////   |> route(
////     method: Get,
////     path: "/admin/users",
////     controller: admin_users,
////     middleware: [auth_middleware, logging_middleware],
////   )
//// }
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
//// 4. Multi-segment wildcards (`**`) - lowest priority
////
//// A segment with an extension, such as `photo.jpg`, uses a different order:
//// literal, extension pattern (`*.jpg`), single wildcard, multi-segment
//// wildcard, and parameter last.
////
//// When a route of higher priority fits a segment but not the rest of the
//// path, the router goes back and tries the route of next priority. With the
//// routes `/users/:id/posts` and `/users/**rest`, the path `/users/1/comments`
//// follows `:id`, finds no match after it, and then matches `/users/**rest`
//// with `rest` = `1/comments`.
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
//// ### A parameter name typo <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router_wrong.gleam#L9-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// // Route definition
//// pub fn user_router() {
////   router()
////   |> route(
////     method: Get,
////     path: "/users/:user_id",
////     controller: show_user,
////     middleware: [],
////   )
//// }
////
//// // Controller (WRONG - fails at runtime)
//// pub fn show_user(request: Request, _context, _services) -> Response {
////   // Should be "user_id"
////   case get_param(request, "id") {
////     // This never runs
////     Ok(param) -> text_response(status.ok, "User " <> param.value)
////     // Always hits this branch
////     Error(message) -> text_response(status.bad_request, message)
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
import gleam/order
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
  Router(
    trie: trie_module.RadixTrie(RouteHandler(context, services)),
    /// Each method that a route has, once. `allowed_methods` tries them when
    /// no route matches a request.
    methods: List(Method),
  )
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
/// ### Build a router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L36-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn app_router() {
///   router()
///   |> route(method: Get, path: "/", controller: home, middleware: [])
///   |> route(
///     method: Get,
///     path: "/users/:id",
///     controller: show_user,
///     middleware: [],
///   )
/// }
/// ```
///
/// Guide: [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
pub fn router() -> Router(context, services) {
  Router(trie: trie_module.new(), methods: [])
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
/// ### Add routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L47-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn add_routes(router) {
///   // Simple route
///   let router =
///     route(
///       router,
///       method: Get,
///       path: "/",
///       controller: home_controller,
///       middleware: [],
///     )
///
///   // Route with path parameter
///   let router =
///     route(
///       router,
///       method: Get,
///       path: "/users/:id",
///       controller: show_user,
///       middleware: [],
///     )
///
///   // Route with middleware
///   let router =
///     route(
///       router,
///       method: Post,
///       path: "/admin/users",
///       controller: create_user,
///       middleware: [auth, logging],
///     )
///
///   // Wildcard route for static files
///   route(
///     router,
///     method: Get,
///     path: "/assets/**path",
///     controller: serve_static,
///     middleware: [],
///   )
/// }
/// ```
///
/// Guide: [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
pub fn route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_function: fn(Request, context, services) -> Response,
  middleware middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) {
  let segments = parser.parse_pattern(path_pattern)
  let method_string = method_key(method_value)
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  let param_names = extract_param_names_from_segments(segments)

  let handler =
    RouteHandler(
      controller: controller_function,
      middleware: middleware_wrappers,
      streaming: False,
      param_names: param_names,
    )

  let updated_trie =
    trie_module.insert(router_value.trie, method_string, segments, handler)

  Router(
    trie: updated_trie,
    methods: add_method(router_value.methods, method_value),
  )
}

/// Add a streaming route to the router
///
/// Registers a route that receives the request body as a stream of `Result` items
/// instead of a buffered `Text` or `Bytes` body. Use this for large file uploads,
/// proxying external APIs, or any request body > 10MB.
///
/// The controller receives `request.body` as
/// `Stream(Yielder(Result(BitArray, BodyReadError)))`. Process chunks as they
/// arrive without buffering the entire body in memory. Each item is
/// `Ok(chunk)`, or one `Error(MalformedBody)` when a read from the
/// connection fails, and the stream ends after that item.
///
/// ## Example
///
/// ### Add streaming routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L88-L102"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn add_upload_routes(router) {
///   router
///   |> stream_route(
///     method: Post,
///     path: "/upload",
///     controller: handle_upload,
///     middleware: [auth],
///   )
///   |> stream_route(
///     method: Put,
///     path: "/files/:id",
///     controller: replace_file,
///     middleware: [],
///   )
/// }
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
///
/// Guide: [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html).
pub fn stream_route(
  router_value: Router(context, services),
  method method_value: Method,
  path path_pattern: String,
  controller controller_function: fn(Request, context, services) -> Response,
  middleware middleware_list: List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) {
  let segments = parser.parse_pattern(path_pattern)
  let method_string = method_key(method_value)
  let middleware_wrappers = list.map(middleware_list, wrap_middleware)
  let param_names = extract_param_names_from_segments(segments)

  let handler =
    RouteHandler(
      controller: controller_function,
      middleware: middleware_wrappers,
      streaming: True,
      param_names: param_names,
    )

  let updated_trie =
    trie_module.insert(router_value.trie, method_string, segments, handler)

  Router(
    trie: updated_trie,
    methods: add_method(router_value.methods, method_value),
  )
}

/// Add the routes of another router under a path prefix and an entry function
///
/// Each route of `inner_router` becomes a route of this router. Its path is
/// `prefix` followed by the path of the route. When a request matches it,
/// Dream calls `enter` with the request, this router's context, the services
/// and `next`. `next` runs the route's own middleware and then its
/// controller, with the context that `enter` gives to it.
///
/// `enter` has the shape of a middleware, but `next` can take a different
/// context type. This lets controllers in the scope take a context that
/// holds more, for example a signed-in user. An ordinary middleware also fits
/// as `enter`, when the context type stays the same. `enter` can answer
/// without a call to `next`, for example with `401`.
///
/// ## Example
///
/// `require_member` turns the app's `Context` into a `MemberContext`, or
/// answers `401`. `cache_for_a_minute` is an ordinary middleware.
///
/// ### Add a member area and a plain group <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_routing_scope_app.gleam#L85-L105"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// fn member_routes() -> Router(MemberContext, EmptyServices) {
///   router()
///   |> route(method: Get, path: "/", controller: show_profile, middleware: [])
///   |> route(
///     method: Get,
///     path: "/teams/:team_id",
///     controller: show_team,
///     middleware: [],
///   )
/// }
///
/// fn public_routes() -> Router(Context, EmptyServices) {
///   router()
///   |> route(method: Get, path: "/about", controller: show_about, middleware: [])
/// }
///
/// pub fn create_router() -> Router(Context, EmptyServices) {
///   router()
///   |> scope(path: "/members", with: require_member, routes: member_routes())
///   |> scope(path: "", with: cache_for_a_minute, routes: public_routes())
/// }
/// ```
///
/// ## Rules
///
/// - **Prefix.** Dream splits the prefix and the route path at each `/`,
///   drops the empty parts, and joins the two lists. So a slash at the start
///   or the end of the prefix does not matter: `"/admin"`, `"admin"` and
///   `"/admin/"` are the same prefix. `"/admin"` with the route `"/"` gives
///   `/admin`, and with `"/users/:id"` it gives `/admin/users/:id`. Give
///   `path: ""` to group routes with no prefix.
/// - **Parameters.** The prefix can have parameters and wildcards, as a route
///   path can. The controller gets the parameters of the prefix first, then
///   those of the route. Give each parameter a name that is not used again
///   in the full path: `get_param` finds the first parameter of a name.
/// - **Order.** On the way in, `enter` runs first, then the middleware of the
///   route in list order, then the controller. A scope in a scope runs the
///   `enter` of the outer scope first.
/// - **Streaming.** A route that `stream_route` added stays a streaming
///   route.
/// - **No match.** Routes from a scope give `404` and `405` (with `Allow`)
///   as other routes do, and `allowed_methods` lists their methods.
/// - **The same method and path.** The route added last replaces the other,
///   as with `route`. A route from a scope replaces an earlier route of this
///   router, and a later `route` call replaces a route from a scope.
/// - `find_route` gives a route from a scope with an empty `middleware` list:
///   its `controller` runs `enter`, the route's middleware and its
///   controller.
///
/// Guide: [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
pub fn scope(
  router_value: Router(outer, services),
  path prefix: String,
  with enter: fn(
    Request,
    outer,
    services,
    fn(Request, inner, services) -> Response,
  ) -> Response,
  routes inner_router: Router(inner, services),
) -> Router(outer, services) {
  let prefix_segments = parser.parse_pattern(prefix)
  let prefix_param_names = extract_param_names_from_segments(prefix_segments)
  let updated_trie =
    insert_scoped_routes(
      router_value.trie,
      trie_module.routes(inner_router.trie),
      prefix_segments,
      prefix_param_names,
      enter,
    )

  Router(
    trie: updated_trie,
    methods: list.fold(inner_router.methods, router_value.methods, add_method),
  )
}

/// Inserts each route of a scope at its prefixed path
fn insert_scoped_routes(
  trie: trie_module.RadixTrie(RouteHandler(outer, services)),
  inner_routes: List(#(String, List(Segment), RouteHandler(inner, services))),
  prefix_segments: List(Segment),
  prefix_param_names: List(String),
  enter: fn(Request, outer, services, fn(Request, inner, services) -> Response) ->
    Response,
) -> trie_module.RadixTrie(RouteHandler(outer, services)) {
  case inner_routes {
    [] -> trie
    [#(method_string, segments, handler), ..rest] -> {
      let scoped = scoped_handler(handler, prefix_param_names, enter)
      let updated_trie =
        trie_module.insert(
          trie,
          method_string,
          list.append(prefix_segments, segments),
          scoped,
        )
      insert_scoped_routes(
        updated_trie,
        rest,
        prefix_segments,
        prefix_param_names,
        enter,
      )
    }
  }
}

/// The handler of a route from a scope: `enter`, then the route's own chain
fn scoped_handler(
  handler: RouteHandler(inner, services),
  prefix_param_names: List(String),
  enter: fn(Request, outer, services, fn(Request, inner, services) -> Response) ->
    Response,
) -> RouteHandler(outer, services) {
  RouteHandler(
    controller: enter_scope(
      enter,
      build_controller_chain(handler.middleware, handler.controller),
    ),
    middleware: [],
    streaming: handler.streaming,
    param_names: list.append(prefix_param_names, handler.param_names),
  )
}

/// A controller that calls `enter` with the route's chain as `next`
fn enter_scope(
  enter: fn(Request, outer, services, fn(Request, inner, services) -> Response) ->
    Response,
  inner_chain: fn(Request, inner, services) -> Response,
) -> fn(Request, outer, services) -> Response {
  fn(request, context, services) {
    enter(request, context, services, inner_chain)
  }
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
/// ### Find a route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L104-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn find_user_params(router, request) {
///   let app_router =
///     router
///     |> route(
///       method: Get,
///       path: "/users/:id",
///       controller: show_user,
///       middleware: [],
///     )
///
///   case find_route(app_router, request) {
///     Some(#(_route, params)) -> {
///       // route.controller is show_user
///       // params is [#("id", "123")] if path was "/users/123"
///       params
///     }
///     // No route matched
///     None -> []
///   }
/// }
/// ```
pub fn find_route(
  router_value: Router(context, services),
  request: Request,
) -> option.Option(#(Route(context, services), List(#(String, String)))) {
  let method_string = method_key(request.method)
  let path_segments = split_path(request.path)

  case trie_module.lookup(router_value.trie, method_string, path_segments) {
    option.Some(trie_module.Match(handler, params)) -> {
      // Params are accumulated in reverse order during traversal, so reverse them
      // to get path order (first param in path = first in list)
      let reversed_params = list.reverse(params)
      let remapped_params =
        remap_params_to_route_names(reversed_params, handler.param_names)

      let route =
        Route(
          method: request.method,
          path: request.path,
          controller: handler.controller,
          middleware: handler.middleware,
          streaming: handler.streaming,
        )
      option.Some(#(route, remapped_params))
    }
    option.None -> option.None
  }
}

/// The methods of the routes that match the request's path
///
/// Gives each method for which a route matches the path of the request, in
/// alphabetical order of the method names, so `["DELETE", "GET", "POST"]`
/// for routes of `GET`, `POST` and `DELETE`. Gives `[]` when no route
/// matches the path. The method of the request does not matter. A path can
/// match more than one route pattern: a `GET` route of `/users/new` and a
/// `POST` route of `/users/:id` both match `/users/new`, so it gets `GET`
/// and `POST`.
///
/// Dream answers a request whose path matches a route, but not with the
/// request's method, with `405 Method Not Allowed` and these methods in the
/// `Allow` header. A request whose path matches no route gets `404`.
///
/// It runs one route lookup for each method of the router, so call it only
/// when `find_route` found no route.
///
/// ## Example
///
/// ### Find the methods of a path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router.gleam#L125-L138"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn item_methods(request) {
///   let app_router =
///     router()
///     |> route(method: Get, path: "/items/:id", controller: home, middleware: [])
///     |> route(
///       method: Delete,
///       path: "/items/:id",
///       controller: home,
///       middleware: [],
///     )
///
///   // POST /items/7 gives [Delete, Get], and POST /users gives []
///   allowed_methods(app_router, request)
/// }
/// ```
pub fn allowed_methods(
  router_value: Router(context, services),
  request: Request,
) -> List(Method) {
  let path_segments = split_path(request.path)
  router_value.methods
  |> list.filter(fn(method) {
    option.is_some(trie_module.lookup(
      router_value.trie,
      method_key(method),
      path_segments,
    ))
  })
  |> list.sort(compare_method_names)
}

fn compare_method_names(first: Method, second: Method) -> order.Order {
  string.compare(
    request.method_to_string(first),
    request.method_to_string(second),
  )
}

/// Adds a method to the list of the router's methods when it is not there yet
fn add_method(methods: List(Method), method: Method) -> List(Method) {
  case list.contains(methods, method) {
    True -> methods
    False -> [method, ..methods]
  }
}

/// Split a path into segments for trie lookup
fn split_path(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(is_non_empty_segment)
}

/// Check if a segment is non-empty
fn is_non_empty_segment(segment: String) -> Bool {
  segment != ""
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
        option.Some(param_name) -> [param_name, ..rest_names]
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
    trie_module.LiteralExtension(_, _) -> option.None
    trie_module.Literal(_) -> option.None
  }
}

/// Remap params extracted during trie traversal to match route's param names
///
/// Params are extracted using the trie node's param names (which may differ
/// from the route's param names when routes share param positions). This function
/// remaps them to the correct names based on the matched route's param_names.
///
/// Both lists are in path order (first param first) and have the same length:
/// the route gives one name for each param that the trie extracted.
fn remap_params_to_route_names(
  extracted_params: List(#(String, String)),
  route_param_names: List(String),
) -> List(#(String, String)) {
  list.map2(extracted_params, route_param_names, rename_param)
}

fn rename_param(param: #(String, String), name: String) -> #(String, String) {
  #(name, param.1)
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
///
/// ## Example
///
/// ### Wrap a controller in middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_router_build_controller_chain.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request}
/// import dream/http/response.{type Response, Text, text_response}
/// import dream/http/status.{ok}
/// import dream/router.{type Middleware, Middleware, build_controller_chain}
///
/// fn controller(_request: Request, _context, _services) -> Response {
///   text_response(ok, "controller")
/// }
///
/// fn wrap(label: String) -> Middleware(context, services) {
///   Middleware(fn(request, context, services, next) {
///     let response = next(request, context, services)
///     case response.body {
///       Text(body) -> text_response(response.status, label <> "(" <> body <> ")")
///       _ -> response
///     }
///   })
/// }
///
/// pub fn handle(request: Request) -> Response {
///   let chain = build_controller_chain([wrap("outer"), wrap("inner")], controller)
///   // The first middleware is the outermost: "outer(inner(controller))"
///   chain(request, Nil, Nil)
/// }
/// ```
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
    [first_middleware, ..rest] -> {
      case first_middleware {
        Middleware(middleware_function) -> {
          let wrapped_controller =
            create_wrapped_controller(middleware_function, controller)
          build_chain_recursive(rest, wrapped_controller)
        }
      }
    }
  }
}

/// Wrap a controller with a middleware function
fn create_wrapped_controller(
  middleware_function: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) -> Response,
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  wrap_controller_with_middleware(middleware_function, controller)
}

/// Create a wrapped controller that applies middleware
///
/// This is a named function to avoid anonymous functions in production code.
fn wrap_controller_with_middleware(
  middleware_function: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) -> Response,
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  apply_middleware_to_controller(middleware_function, controller)
}

/// Apply middleware to a controller, creating a wrapped controller function
fn apply_middleware_to_controller(
  middleware_function: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) -> Response,
  controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  fn(request, context, services) {
    middleware_function(request, context, services, controller)
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Wrap a middleware function in the Middleware type
fn wrap_middleware(
  middleware_function: fn(
    Request,
    context,
    services,
    fn(Request, context, services) -> Response,
  ) -> Response,
) -> Middleware(context, services) {
  Middleware(middleware_function)
}

/// The trie key of a method. `Other` gets a space before its name. A space
/// cannot be part of a method token, so `Other("GET")` never shares the key
/// of `Get`, and a route matches only a request with an equal method.
fn method_key(method: Method) -> String {
  case method {
    request.Other(name) -> " " <> name
    _ -> request.method_to_string(method)
  }
}
