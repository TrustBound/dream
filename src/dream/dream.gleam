//// Core Dream server type and shared functionality
////
//// This module provides the generic Dream server type and core routing
//// functionality that is shared across all server implementations.
////
//// Most applications will use `dream/servers/mist/server` instead of this
//// module directly. This module contains the core types and routing logic
//// that the server implementations build upon.

import dream/http/cookie.{type Cookie, simple_cookie}
import dream/http/header.{type Header, Header, header_name, header_value}
import dream/http/request.{type Request, set_params}
import dream/http/response.{type Response, Response, Text}
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
///
/// This type holds all the configuration needed to run a web server:
/// router, context template, services, and server-specific settings.
///
/// ## Fields
///
/// - `server`: The underlying HTTP server (Mist Builder)
/// - `router`: Optional router with all routes configured
/// - `context`: Template context cloned for each request
/// - `services`: Optional services instance (database, cache, etc.)
/// - `max_body_size`: Maximum allowed request body size in bytes
///
/// ## Type Parameters
///
/// The Dream type is generic over three parameters:
///
/// 1. **server**: The underlying server type (usually Mist)
/// 2. **context**: Your application's context type
/// 3. **services**: Your application's services type
///
/// This allows the type system to verify that your router, controllers,
/// and middleware all use compatible types.
///
/// ## Example
///
/// ```gleam
/// import dream/servers/mist/server as dream
/// import mist.{type Connection, type ResponseData}
///
/// // Your application types
/// pub type MyContext {
///   MyContext(request_id: String, user: Option(User))
/// }
///
/// pub type Services {
///   Services(db: Connection, cache: Cache)
/// }
///
/// // Dream server with your types
/// // Type: Dream(mist.Builder(Connection, ResponseData), MyContext, Services)
/// let server = 
///   dream.new()
///   |> dream.context(MyContext(request_id: "", user: None))
///   |> dream.services(Services(db: my_db, cache: my_cache))
///   |> dream.router(my_router)
/// ```
pub opaque type Dream(server, context, services) {
  Dream(
    server: server,
    router: option.Option(Router(context, services)),
    context: context,
    services: option.Option(services),
    max_body_size: Int,
    bind_interface: option.Option(String),
  )
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
/// ## Better Alternative
///
/// Use the builder pattern for better readability and type safety:
///
/// ```gleam
/// server.new()
/// |> server.context(MyContext)
/// |> server.services(MyServices)
/// |> server.router(my_router)
/// |> server.max_body_size(10_000_000)
/// |> server.bind("0.0.0.0")
/// ```
pub fn create(
  server server: server,
  router router: option.Option(Router(context, services)),
  context context: context,
  services services: option.Option(services),
  max_body_size max_body_size: Int,
  bind_interface bind_interface: option.Option(String),
) -> Dream(server, context, services) {
  Dream(
    server: server,
    router: router,
    context: context,
    services: services,
    max_body_size: max_body_size,
    bind_interface: bind_interface,
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
/// ```gleam
/// // You must explicitly acknowledge the risks
/// let mist_server = dream.get_server(app, risks_understood: True)
/// // Now you have raw Mist types - your code is coupled to Mist
/// ```
///
/// If you must use this, isolate it in a single module and document why.
///
/// ## Panics
///
/// Panics if `risks_understood` is `False`. You must pass `True` to proceed.
pub fn get_server(
  dream: Dream(server, context, services),
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
/// Returns the router if one has been set, or None if not yet configured.
///
/// ## Example
///
/// ```gleam
/// let app = server.new() |> server.router(my_router)
/// case dream.get_router(app) {
///   Some(router) -> // Router is configured
///   None -> // No router yet
/// }
/// ```
pub fn get_router(
  dream: Dream(server, context, services),
) -> option.Option(Router(context, services)) {
  dream.router
}

/// Get the context configured for this Dream instance
///
/// Returns the context value that will be passed to all controllers.
///
/// ## Example
///
/// ```gleam
/// let app = server.new() |> server.context(MyContext(user: None))
/// let ctx = dream.get_context(app)
/// ```
pub fn get_context(dream: Dream(server, context, services)) -> context {
  dream.context
}

/// Get the services configured for this Dream instance
///
/// Returns the services if they have been set, or None if not yet configured.
///
/// ## Example
///
/// ```gleam
/// let app = server.new() |> server.services(my_services)
/// case dream.get_services(app) {
///   Some(services) -> // Services are configured
///   None -> // No services yet
/// }
/// ```
pub fn get_services(
  dream: Dream(server, context, services),
) -> option.Option(services) {
  dream.services
}

/// Get the max body size configured for this Dream instance
///
/// Returns the maximum request body size in bytes. Requests with bodies
/// larger than this will be rejected.
///
/// ## Example
///
/// ```gleam
/// let app = server.new() |> server.max_body_size(5_000_000)
/// dream.get_max_body_size(app) // Returns 5_000_000
/// ```
pub fn get_max_body_size(dream: Dream(server, context, services)) -> Int {
  dream.max_body_size
}

/// Get the bind interface configured for this Dream instance
///
/// Returns the network interface the server will bind to if configured,
/// or None if using the default interface.
///
/// ## Example
///
/// ```gleam
/// let app = server.new() |> server.bind("0.0.0.0")
/// case dream.get_bind_interface(app) {
///   Some(interface) -> // Will bind to specified interface
///   None -> // Will use default interface
/// }
/// ```
pub fn get_bind_interface(
  dream: Dream(server, context, services),
) -> option.Option(String) {
  dream.bind_interface
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
/// If no route matches, returns a 404 response.
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
/// HTTP response from the controller or 404 if no route matches
///
/// ## Example
///
/// ```gleam
/// // Internal use - normally called by the request handler
/// let response = route_request(
///   my_router,
///   incoming_request,
///   request_context,
///   my_services
/// )
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
    option.None ->
      Response(
        status: 404,
        body: Text("Route not found"),
        headers: [
          Header("Content-Type", "text/plain; charset=utf-8"),
        ],
        cookies: [],
        content_type: option.Some("text/plain; charset=utf-8"),
      )
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
/// ```gleam
/// import dream/http/header.{Header}
///
/// let headers = [
///   Header("Content-Type", "application/json"),
///   Header("Cookie", "session=abc123; theme=dark"),
/// ]
///
/// let cookies = parse_cookies_from_headers(headers)
/// // Returns: [
/// //   Cookie(name: "session", value: "abc123", ...),
/// //   Cookie(name: "theme", value: "dark", ...)
/// // ]
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
/// ```gleam
/// let cookie_str = "session=abc123; theme=dark; lang=en"
/// let cookies = parse_cookie_string(cookie_str)
/// // Returns: [
/// //   simple_cookie("session", "abc123"),
/// //   simple_cookie("theme", "dark"),
/// //   simple_cookie("lang", "en")
/// // ]
/// ```
pub fn parse_cookie_string(cookie_string: String) -> List(Cookie) {
  cookie_string
  |> string.split(";")
  |> list.map(parse_cookie_pair)
}

fn parse_cookie_pair(cookie_pair: String) -> Cookie {
  case string.split(cookie_pair, "=") {
    [name, value] -> {
      let name = string.trim(name)
      let value = string.trim(value)
      simple_cookie(name, value)
    }
    _ -> {
      let name = string.trim(cookie_pair)
      simple_cookie(name, "")
    }
  }
}
