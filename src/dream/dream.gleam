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
import dream/router.{type Router, build_controller_chain, find_route}
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
pub type Dream(server, context, services) {
  Dream(
    server: server,
    router: option.Option(Router(context, services)),
    context: context,
    services: option.Option(services),
    max_body_size: Int,
  )
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
    option.Some(#(route, params)) -> {
      let request_with_params = set_params(request, params)

      // Build the controller chain from middleware + controller
      let controller_chain =
        build_controller_chain(route.middleware, route.controller)

      // Execute the chain (which will run all middleware then the controller)
      controller_chain(request_with_params, context, services)
    }
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
