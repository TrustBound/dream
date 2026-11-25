//// Core Dream server type and shared functionality
////
//// Guides: [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) and [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html).
////
//// This module provides the generic Dream server type and core routing
//// functionality that is shared across all server implementations.
////
//// Most applications will use `dream/servers/mist/server` instead of this
//// module directly. This module contains the core types and routing logic
//// that the server implementations build upon.

import dream/http/cookie.{type Cookie, simple_cookie}
import dream/http/header.{type Header, header_name, header_value}
import dream/http/request.{type Request, set_params}
import dream/http/response.{type Response}
import dream/internal/built_in_answer
import dream/router.{type Route, type Router, build_controller_chain, find_route}
import gleam/list
import gleam/option
import gleam/string

/// Generic Dream server type
///
/// Represents a configured Dream web server, parameterized over:
/// - `server`: The underlying server implementation (e.g., Mist)
/// - `context`: Your application's context type
/// - `services`: Your application's services type
/// - `router`: Whether the app has a router yet: `NoRouter`, or the
///   `Router(context, services)` that `router()` gave it
///
/// This type holds all the configuration needed to run a web server:
/// router, context template, services, and server-specific settings.
///
/// ## Fields
///
/// - `server`: The underlying HTTP server (Mist Builder)
/// - `router`: `NoRouter`, or the router with all routes configured
/// - `context`: Template context cloned for each request
/// - `services`: Services instance (database, cache, etc.)
/// - `max_body_size`: Maximum allowed request body size in bytes
///
/// ## Type Parameters
///
/// The Dream type is generic over four parameters:
///
/// 1. **server**: The underlying server type (usually Mist)
/// 2. **context**: Your application's context type
/// 3. **services**: Your application's services type
/// 4. **router**: `NoRouter` before `router()`, `Router(context, services)` after
///
/// This allows the type system to verify that your router, controllers,
/// and middleware all use compatible types.
///
/// ## Builder Order
///
/// Call `context()` and `services()` before `router()`, then `listen()`.
/// The compiler enforces this order:
///
/// - A router's type includes the context and services types:
///   `Router(context, services)`. `context()` and `services()` change those
///   types, so a router given before them cannot stay in the app. That is why
///   `context()` and `services()` accept only an app whose `router` parameter
///   is `NoRouter`.
/// - `listen()` and `listen_with_handle()` accept only an app whose `router`
///   parameter is a `Router(context, services)`, so an app without a router
///   does not compile.
///
/// ## Example
///
/// ### Build a Dream server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_type.gleam#L12-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// // Your application types
/// pub type MyContext {
///   MyContext(request_id: String, user: Option(User))
/// }
///
/// pub type Services {
///   Services(database_url: String, cache_size: Int)
/// }
///
/// // Dream server with your types
/// pub fn create_server() -> Dream(
///   mist.Builder(Connection, ResponseData),
///   MyContext,
///   Services,
///   Router(MyContext, Services),
/// ) {
///   server.new()
///   |> server.context(MyContext(request_id: "", user: None))
///   |> server.services(Services(
///     database_url: "postgres://localhost/app",
///     cache_size: 100,
///   ))
///   |> server.router(my_router())
/// }
/// ```
pub opaque type Dream(server, context, services, router) {
  Dream(
    server: server,
    router: router,
    context: context,
    services: services,
    max_body_size: Int,
    bind_interface: option.Option(String),
    tls: option.Option(Tls),
    shutdown_timeout: Int,
  )
}

/// The router state of an app that has no router yet
///
/// `dream/servers/mist/server.new()` returns an app whose `router` type
/// parameter is `NoRouter`. `router()` replaces it with the
/// `Router(context, services)` it is given. `context()` and `services()`
/// accept only a `NoRouter` app, and `listen()` does not accept one.
pub type NoRouter {
  NoRouter
}

/// The certificate and key files a server uses to serve HTTPS
///
/// Both are paths to PEM files. Set them with
/// `dream/servers/mist/server.tls()`.
pub type Tls {
  Tls(certfile: String, keyfile: String)
}

// Accessor functions for internal use by server modules

/// Create a new Dream instance with explicit configuration
///
/// ⚠️ **Warning: This is a low-level constructor**
///
/// This function is primarily for internal Dream framework use. Most users should
/// use the builder pattern via `dream/servers/mist/server.new()` instead.
///
/// ## When You Might Need This
///
/// You might use this if:
/// - You're building custom server adapters for Dream
/// - You're testing Dream internals
/// - You need to construct a Dream instance programmatically with all fields at once
///
/// `router` is `NoRouter` for an app without a router, or the
/// `Router(context, services)` the app serves. Only an app with a router can
/// listen.
///
/// ## Better Alternative
///
/// Use the builder pattern for better readability and type safety:
///
/// ### Use the builder <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_builder.gleam#L27-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn create_server() {
///   server.new()
///   |> server.context(MyContext)
///   |> server.services(MyServices)
///   |> server.router(my_router())
///   |> server.max_body_size(10_000_000)
///   |> server.bind("0.0.0.0")
/// }
/// ```
pub fn create(
  server server: server,
  router router: router,
  context context: context,
  services services: services,
  max_body_size max_body_size: Int,
  bind_interface bind_interface: option.Option(String),
) -> Dream(server, context, services, router) {
  Dream(
    server: server,
    router: router,
    context: context,
    services: services,
    max_body_size: max_body_size,
    bind_interface: bind_interface,
    tls: option.None,
    shutdown_timeout: 30_000,
  )
}

/// Get the underlying server instance from a Dream instance
///
/// ⚠️ **Warning: This breaks Dream's server abstraction**
///
/// This function exposes the underlying server implementation (currently `mist.Builder`).
/// Using this in your application code creates tight coupling to Mist and prevents
/// Dream from switching server implementations in the future.
///
/// ## The `risks_understood` Parameter
///
/// You **must** explicitly pass `risks_understood: True` to call this function.
/// Passing `False` will panic. This forces you to consciously acknowledge that
/// you're breaking Dream's abstraction.
///
/// ## When You Might Need This
///
/// You might legitimately need this if:
/// - You need to configure Mist-specific features not exposed by Dream
/// - You're integrating with libraries that expect raw Mist types
/// - You're debugging server-level issues
///
/// ## Risks You're Accepting
///
/// By passing `risks_understood: True`, you acknowledge:
/// - **Vendor lock-in**: Your code becomes coupled to Mist
/// - **Breaking changes**: If Dream switches servers or upgrades Mist, your code breaks
/// - **Lost abstractions**: You bypass Dream's carefully designed API
///
/// ## Better Alternatives
///
/// Before using this, check if Dream provides:
/// - `server.bind()` for network interface configuration
/// - `server.max_body_size()` for request size limits
/// - Or open a GitHub issue requesting the feature you need
///
/// ## Example
///
/// ### Get the Mist server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L38-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn raw_server(app) -> mist.Builder(Connection, ResponseData) {
///   // You must explicitly acknowledge the risks
///   let mist_server = dream.get_server(app, risks_understood: True)
///   // Now you have raw Mist types - your code is coupled to Mist
///   mist_server
/// }
/// ```
///
/// If you must use this, isolate it in a single module and document why.
///
/// ## Panics
///
/// Panics if `risks_understood` is `False`. You must pass `True` to proceed.
pub fn get_server(
  dream: Dream(server, context, services, router),
  risks_understood risks: Bool,
) -> server {
  case risks {
    True -> dream.server
    False ->
      panic as "dream.get_server() requires risks_understood: True. This function breaks Dream's server abstraction and couples your code to Mist. Read the documentation to understand the risks before proceeding."
  }
}

/// Get the router configured for this Dream instance
///
/// Returns `NoRouter` before `router()` is called, and the
/// `Router(context, services)` after it. The type says which one you get.
///
/// ## Example
///
/// ### Check for a router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L45-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn configured_router() -> Router(EmptyContext, EmptyServices) {
///   let app = server.new() |> server.router(my_router())
///   // Returns the router; before router(), get_router returns NoRouter
///   dream.get_router(app)
/// }
/// ```
pub fn get_router(dream: Dream(server, context, services, router)) -> router {
  dream.router
}

/// Get the context configured for this Dream instance
///
/// Returns the context value that will be passed to all controllers.
///
/// ## Example
///
/// ### Get the context <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L51-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn configured_context() -> MyContext {
///   let app = server.new() |> server.context(MyContext(user: None))
///   let context = dream.get_context(app)
///   context
/// }
/// ```
pub fn get_context(dream: Dream(server, context, services, router)) -> context {
  dream.context
}

/// Get the services configured for this Dream instance
///
/// Returns the services given to `services()`, or `EmptyServices` when
/// `services()` was not called.
///
/// ## Example
///
/// ### Check for services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L57-L61"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn configured_services() -> MyServices {
///   let app = server.new() |> server.services(my_services())
///   // Returns my_services(); without services(), it returns EmptyServices
///   dream.get_services(app)
/// }
/// ```
pub fn get_services(
  dream: Dream(server, context, services, router),
) -> services {
  dream.services
}

/// Get the max body size configured for this Dream instance
///
/// Returns the maximum request body size in bytes. Requests with bodies
/// larger than this will be rejected.
///
/// ## Example
///
/// ### Get the max body size <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L63-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn configured_max_body_size() -> Int {
///   let app = server.new() |> server.max_body_size(5_000_000)
///   dream.get_max_body_size(app)
///   // Returns 5_000_000
/// }
/// ```
pub fn get_max_body_size(
  dream: Dream(server, context, services, router),
) -> Int {
  dream.max_body_size
}

/// Get the bind interface configured for this Dream instance
///
/// Returns the network interface the server will bind to if configured,
/// or None if using the default interface.
///
/// ## Example
///
/// ### Get the bind interface <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L69-L75"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn bind_status() -> String {
///   let app = server.new() |> server.bind("0.0.0.0")
///   case dream.get_bind_interface(app) {
///     Some(interface) -> "Will bind to " <> interface
///     None -> "Will use the default interface"
///   }
/// }
/// ```
pub fn get_bind_interface(
  dream: Dream(server, context, services, router),
) -> option.Option(String) {
  dream.bind_interface
}

/// Set the certificate and key files for serving HTTPS
///
/// This is a low-level function for server adapters. Use
/// `dream/servers/mist/server.tls()` in your application.
///
/// ## Example
///
/// ### Set the TLS files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_set_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/dream.{type Tls, Tls, get_tls, set_tls}
/// import dream/servers/mist/server
/// import gleam/option.{type Option, Some}
///
/// pub fn tls_files() -> Option(Tls) {
///   let app =
///     server.new()
///     |> set_tls(Some(Tls(certfile: "cert.pem", keyfile: "key.pem")))
///   // Some(Tls(certfile: "cert.pem", keyfile: "key.pem"))
///   get_tls(app)
/// }
/// ```
pub fn set_tls(
  dream: Dream(server, context, services, router),
  tls: option.Option(Tls),
) -> Dream(server, context, services, router) {
  Dream(..dream, tls: tls)
}

/// Get the certificate and key files for serving HTTPS, if any
///
/// Returns `None` when the server serves plain HTTP.
///
/// ## Example
///
/// ### Read the TLS files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_get_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/dream.{type Tls, get_tls}
/// import dream/servers/mist/server
/// import gleam/option.{type Option}
///
/// pub fn plain_http_tls() -> Option(Tls) {
///   // A server with no certificate and key files serves plain HTTP: None
///   get_tls(server.new())
/// }
/// ```
pub fn get_tls(
  dream: Dream(server, context, services, router),
) -> option.Option(Tls) {
  dream.tls
}

/// Set how long, in milliseconds, a stopping server waits for running requests
///
/// This is a low-level function for server adapters. Use
/// `dream/servers/mist/server.shutdown_timeout()` in your application.
///
/// ## Example
///
/// ### Set the shutdown timeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_set_shutdown_timeout.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/dream.{get_shutdown_timeout, set_shutdown_timeout}
/// import dream/servers/mist/server
///
/// pub fn ten_seconds() -> Int {
///   let app =
///     server.new()
///     |> set_shutdown_timeout(10_000)
///   // 10_000
///   get_shutdown_timeout(app)
/// }
/// ```
pub fn set_shutdown_timeout(
  dream: Dream(server, context, services, router),
  milliseconds: Int,
) -> Dream(server, context, services, router) {
  Dream(..dream, shutdown_timeout: milliseconds)
}

/// Get how long, in milliseconds, a stopping server waits for running requests
///
/// The default is 30_000 (30 seconds).
///
/// ## Example
///
/// ### Read the shutdown timeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_get_shutdown_timeout.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/dream.{get_shutdown_timeout}
/// import dream/servers/mist/server
///
/// pub fn default_shutdown_timeout() -> Int {
///   // A new server waits at most 30 seconds: 30_000
///   get_shutdown_timeout(server.new())
/// }
/// ```
pub fn get_shutdown_timeout(
  dream: Dream(server, context, services, router),
) -> Int {
  dream.shutdown_timeout
}

/// Route a request through the router
///
/// Takes an incoming HTTP request, matches it against the router's routes,
/// executes any middleware, calls the appropriate controller, and returns
/// the response.
///
/// This is the core routing function that:
/// 1. Finds a matching route based on method and path
/// 2. Extracts path parameters (e.g., `:id` from `/users/:id`)
/// 3. Builds the middleware chain
/// 4. Executes middleware and controller
/// 5. Returns the response
///
/// If a route matches the path but none has the request's method, returns
/// `405 Method Not Allowed` with an `Allow` header that lists the methods of
/// the path (see `router.allowed_methods`). If no route matches the path,
/// returns `404 Not Found`.
///
/// ## Parameters
///
/// - `router_instance`: Router with all routes configured
/// - `request`: HTTP request to route
/// - `context`: Request-specific context
/// - `services`: Application services (database, cache, etc.)
///
/// ## Returns
///
/// HTTP response from the controller, or the 405 or 404 answer
///
/// ## Example
///
/// ### Route a request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L77-L87"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn handle(
///   my_router,
///   incoming_request: Request,
///   request_context,
///   my_services,
/// ) -> Response {
///   // Internal use - normally called by the request handler
///   let response =
///     route_request(my_router, incoming_request, request_context, my_services)
///   response
/// }
/// ```
pub fn route_request(
  router_instance: Router(context, services),
  request: Request,
  context: context,
  services: services,
) -> Response {
  case find_route(router_instance, request) {
    option.Some(#(route, params)) ->
      execute_route(route, request, params, context, services)
    option.None -> built_in_answer.no_route(router_instance, request)
  }
}

/// Execute a route with its params, middleware, and controller
///
/// Helper function to execute a route that's already been matched.
/// Used by route_request and can be called directly when route is already known
/// (e.g., in server handlers that need to find the route first to determine
/// if it's streaming).
///
/// ## Parameters
///
/// - `route`: The matched route to execute
/// - `request`: HTTP request (may have body/stream already attached)
/// - `params`: Path parameters extracted from the route pattern
/// - `context`: Application context
/// - `services`: Application services
///
/// ## Returns
///
/// HTTP response from the controller
///
/// ## Example
///
/// ### Run a matched route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_execute_route.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/dream.{execute_route}
/// import dream/http/request.{type Request, Get, get_param}
/// import dream/http/response.{type Response, text_response}
/// import dream/http/status.{bad_request, not_found, ok}
/// import dream/router.{find_route, route, router}
/// import gleam/option.{None, Some}
///
/// fn show_user(request: Request, _context, _services) -> Response {
///   case get_param(request, "id") {
///     Ok(param) -> text_response(ok, "User " <> param.value)
///     Error(message) -> text_response(bad_request, message)
///   }
/// }
///
/// pub fn handle(request: Request) -> Response {
///   let app_router =
///     router()
///     |> route(
///       method: Get,
///       path: "/users/:id",
///       controller: show_user,
///       middleware: [],
///     )
///   case find_route(app_router, request) {
///     // execute_route sets the params, then runs the middleware and the
///     // controller: GET /users/7 gives "User 7"
///     Some(#(matched_route, params)) ->
///       execute_route(matched_route, request, params, Nil, Nil)
///     None -> text_response(not_found, "Route not found")
///   }
/// }
/// ```
pub fn execute_route(
  route: Route(context, services),
  request: Request,
  params: List(#(String, String)),
  context: context,
  services: services,
) -> Response {
  let request_with_params = set_params(request, params)

  // Build the controller chain from middleware + controller
  let controller_chain =
    build_controller_chain(route.middleware, route.controller)

  // Execute the chain (which will run all middleware then the controller)
  controller_chain(request_with_params, context, services)
}

/// Parse cookies from HTTP headers
///
/// Extracts cookies from the Cookie header in a list of headers.
/// Parses the cookie string format ("name1=value1; name2=value2") into
/// a list of Cookie objects.
///
/// ## Parameters
///
/// - `headers`: List of HTTP headers to search
///
/// ## Returns
///
/// List of parsed cookies (empty list if no Cookie header found)
///
/// ## Example
///
/// ### Parse cookies from headers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L89-L101"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn request_cookies() -> List(Cookie) {
///   let headers = [
///     Header("Content-Type", "application/json"),
///     Header("Cookie", "session=abc123; theme=dark"),
///   ]
///
///   let cookies = parse_cookies_from_headers(headers)
///   // Returns: [
///   //   Cookie(name: "session", value: "abc123", ...),
///   //   Cookie(name: "theme", value: "dark", ...)
///   // ]
///   cookies
/// }
/// ```
pub fn parse_cookies_from_headers(headers: List(Header)) -> List(Cookie) {
  let cookie_header = list.find(headers, is_cookie_header)

  case cookie_header {
    Ok(header) -> {
      let cookie_string = header_value(header)
      parse_cookie_string(cookie_string)
    }
    Error(_) -> []
  }
}

fn is_cookie_header(header: Header) -> Bool {
  string.lowercase(header_name(header)) == "cookie"
}

/// Parse a cookie header string into a list of cookies
///
/// Parses the raw cookie header value format ("name1=value1; name2=value2")
/// into a list of Cookie objects with simple cookies (no attributes).
///
/// ## Parameters
///
/// - `cookie_string`: Raw Cookie header value
///
/// ## Returns
///
/// List of parsed simple cookies
///
/// ## Example
///
/// ### Parse a cookie string <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream.gleam#L103-L112"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn cookie_string_cookies() -> List(Cookie) {
///   let cookie_header = "session=abc123; theme=dark; lang=en"
///   let cookies = parse_cookie_string(cookie_header)
///   // Returns: [
///   //   simple_cookie("session", "abc123"),
///   //   simple_cookie("theme", "dark"),
///   //   simple_cookie("lang", "en")
///   // ]
///   cookies
/// }
/// ```
pub fn parse_cookie_string(cookie_string: String) -> List(Cookie) {
  cookie_string
  |> string.split(";")
  |> list.map(parse_cookie_pair)
}

fn parse_cookie_pair(cookie_pair: String) -> Cookie {
  case string.split_once(cookie_pair, "=") {
    Ok(#(name, value)) -> {
      let name = string.trim(name)
      let value = string.trim(value)
      simple_cookie(name, value)
    }
    Error(Nil) -> {
      let name = string.trim(cookie_pair)
      simple_cookie(name, "")
    }
  }
}
