//// Route configuration and request matching
////
//// The router matches incoming requests to controllers based on HTTP method and path patterns.
//// It supports path parameters, wildcards, middleware chains, and custom context/services types.
////
//// ## Basic Routing
////
//// ```gleam
//// import dream/router.{route, router}
//// import dream/http/request.{Get, Post}
////
//// pub fn create_router() {
////   router
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
//// Access parameters in your controller with `get_param(request, "id")`.
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
//// router
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
//// ## Route Matching
////
//// Routes are matched in the order they're defined. First match wins.
//// More specific routes should come before general ones:
////
//// ```gleam
//// router
//// |> route(method: Get, path: "/users/new", controller: controllers.new_user, middleware: [])  // Specific
//// |> route(method: Get, path: "/users/:id", controller: controllers.show_user, middleware: []) // General
//// ```

import dream/context.{type AppContext}

// No statuses import needed - using raw Int status codes
import dream/http/header.{Header}
import dream/http/request.{type Method, type Request, Get}
import dream/http/response.{type Response, Response, Text}
import dream/router/pattern
import gleam/list
import gleam/option
import gleam/string

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
/// Routes are matched in the order they're added to the router.
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
/// The router maintains a list of routes and provides them to the server for request matching.
/// It's generic over context and services types so the type system can verify your whole app.
pub type Router(context, services) {
  Router(routes: List(Route(context, services)))
}

/// Placeholder for when you haven't defined services yet
///
/// Use this as your services type during initial development. Replace it with your
/// own services type when you add database connections, caches, or other shared dependencies.
pub type EmptyServices {
  EmptyServices
}

/// Default 404 controller for AppContext
fn default_404_controller(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 404,
    body: Text("Not Found"),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

/// Default route builder starting point
///
/// Creates an empty route that you can configure using the builder pattern.
/// Most applications use `route()` with labeled arguments instead.
///
/// ## Example
///
/// ```gleam
/// route(method: Get, path: "/users/:id", controller: show_user, middleware: [auth])
/// ```
pub const new = Route(
  method: Get,
  path: "/",
  controller: default_404_controller,
  middleware: [],
  streaming: False,
)

/// Empty router with no routes
///
/// Starting point for building your application's router. Chain this with
/// `route()` or `stream_route()` calls to add routes.
///
/// ## Example
///
/// ```gleam
/// router
/// |> route(method: Get, path: "/", controller: home, middleware: [])
/// |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [auth])
/// ```
pub const router = Router(routes: [])

/// Set which HTTP method this route responds to
///
/// Part of the route builder pattern. Specify whether this route handles
/// GET, POST, PUT, DELETE, PATCH, OPTIONS, or HEAD requests.
///
/// Most applications use `route()` with labeled arguments instead of this builder.
///
/// ## Example
///
/// ```gleam
/// import dream/router.{route, router}
/// import dream/http/request.{Get}
///
/// router
/// |> route(method: Get, path: "/users", controller: list_users, middleware: [])
/// ```
pub fn method(
  route: Route(context, services),
  method_value: Method,
) -> Route(context, services) {
  Route(..route, method: method_value)
}

/// Set the URL path pattern for this route
///
/// Part of the route builder pattern. The path can include parameters (`:id`),
/// wildcards (`*`, `**`), and extension patterns (`*.jpg`, `*.{jpg,png}`).
///
/// Most applications use `route()` with labeled arguments instead of this builder.
///
/// ## Example
///
/// ```gleam
/// import dream/router.{route, router}
/// import dream/http/request.{Get}
///
/// router
/// |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
/// ```
pub fn path(
  route: Route(context, services),
  path_value: String,
) -> Route(context, services) {
  Route(..route, path: path_value)
}

/// Set which controller handles requests to this route
///
/// Part of the route builder pattern. The controller is the function that
/// processes the request and returns a response.
///
/// Controllers receive (Request, context, services) and return Response.
///
/// Most applications use `route()` with labeled arguments instead of this builder.
///
/// ## Example
///
/// ```gleam
/// import dream/router.{route, router}
/// import dream/http/request.{Get}
///
/// router
/// |> route(method: Get, path: "/users/:id", controller: show_user, middleware: [])
/// 
/// fn show_user(request, context, services) {
///   // ... handle request
/// }
/// ```
pub fn controller(
  route: Route(context, services),
  controller_function: fn(Request, context, services) -> Response,
) -> Route(context, services) {
  Route(..route, controller: controller_function)
}

/// Add middleware to this route
///
/// Part of the route builder pattern. Middleware intercept requests before
/// they reach the controller and responses before they're sent to the client.
/// They can authenticate users, log requests, transform data, or short-circuit
/// the request early.
///
/// Middleware execute in the order provided: first middleware runs first on
/// the way in, last on the way out (wrapping pattern).
///
/// Most applications use `route()` with labeled arguments instead of this builder.
///
/// ## Example
///
/// ```gleam
/// import dream/router.{route, router}
/// import dream/http/request.{Get}
///
/// router
/// |> route(method: Get, path: "/admin/users", controller: list_users, middleware: [auth, logging])
/// ```
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
///
/// Routes are matched in the order they're added, so put more specific routes first.
/// The path supports parameters (`:id`), wildcards (`*`, `**`), and extensions (`*.jpg`).
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
  router: Router(context, services),
  method method_value: Method,
  path path_value: String,
  controller controller_function: fn(Request, context, services) -> Response,
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
      controller: controller_function,
      middleware: middleware_wrappers,
      streaming: False,
    )
  Router(routes: [route, ..router.routes])
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
  router: Router(context, services),
  method method_value: Method,
  path path_value: String,
  controller controller_function: fn(Request, context, services) -> Response,
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
      controller: controller_function,
      middleware: middleware_wrappers,
      streaming: True,
    )
  Router(routes: [route, ..router.routes])
}

/// Match a path against a pattern and extract parameters
///
/// Returns the extracted parameters if the path matches the pattern, or `None` if it doesn't.
///
/// ## Path Parameters
///
/// ```gleam
/// match_path("/users/:id", "/users/123")
/// // -> Some([#("id", "123")])
///
/// match_path("/users/:user_id/posts/:id", "/users/123/posts/456")
/// // -> Some([#("user_id", "123"), #("id", "456")])
/// ```
///
/// ## Wildcards
///
/// ```gleam
/// // Single-segment wildcard
/// match_path("/assets/*file", "/assets/logo.png")
/// // -> Some([#("file", "logo.png")])
///
/// // Multi-segment wildcard
/// match_path("/files/**path", "/files/docs/guide.pdf")
/// // -> Some([#("path", "docs/guide.pdf")])
///
/// // Extension matching
/// match_path("/images/*.jpg", "/images/photo.jpg")
/// // -> Some([])
///
/// // Multiple extensions
/// match_path("/images/*.{jpg,png}", "/images/photo.jpg")
/// // -> Some([])
/// ```
pub fn match_path(
  pattern_string: String,
  path: String,
) -> option.Option(List(#(String, String))) {
  let pattern_segments =
    string.split(pattern_string, "/") |> list.filter(non_empty_segment)
  let path_segments = string.split(path, "/") |> list.filter(non_empty_segment)

  pattern.match_segments(pattern_segments, path_segments)
}

fn non_empty_segment(segment: String) -> Bool {
  segment != ""
}

/// Find the first route matching the request
///
/// Searches the router's routes in order for one that matches the request's
/// method and path. Returns the matched route and extracted path parameters,
/// or None if no route matches.
///
/// Routes are checked in the order they were added to the router. First match wins.
///
/// ## Parameters
///
/// - `router`: Router with configured routes
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

/// Build a controller chain from middleware and final controller
///
/// Composes middleware with the controller to create a single function. Middleware
/// execute in order on the way in, then in reverse order on the way out.
///
/// For middleware `[auth, logging]` with controller `handle`:
/// Request → auth → logging → handle → logging → auth → Response
pub fn build_controller_chain(
  middleware: List(Middleware(context, services)),
  final_controller: fn(Request, context, services) -> Response,
) -> fn(Request, context, services) -> Response {
  // Reverse middleware list so first added wraps outermost
  let reversed = list.reverse(middleware)
  build_chain_recursive(reversed, final_controller)
}

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
