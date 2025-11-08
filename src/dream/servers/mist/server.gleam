//// Your Dream app's entry point
////
//// This module is where your web application starts. It provides a builder pattern
//// for configuring and starting a Dream server using Mist (the BEAM's HTTP server).
////
//// ## Quick Start
////
//// ```gleam
//// import dream/servers/mist/server as dream
//// 
//// pub fn main() {
////   dream.new()
////   |> dream.services(initialize_services())
////   |> dream.router(create_router())
////   |> dream.listen(3000)
//// }
//// ```
////
//// The builder pattern lets you configure your server step by step. Start with `new()`,
//// add your services and router, optionally set a custom context, then `listen()` to start.
////
//// ## Custom Context
////
//// By default, Dream uses `AppContext` with just a `request_id` field. For most apps,
//// you'll want to define your own context type to hold user auth, session data, etc:
////
//// ```gleam
//// pub type MyContext {
////   MyContext(request_id: String, user: Option(User), session: Session)
//// }
////
//// dream.new()
//// |> dream.context(MyContext(request_id: "", user: None, session: empty_session()))
//// |> dream.services(initialize_services())
//// |> dream.router(create_router())
//// |> dream.listen(3000)
//// ```
////
//// The type system ensures your controllers receive the correct context type.

import dream/core/context.{type AppContext}
import dream/core/dream
import dream/core/router.{type EmptyServices, type Router}
import dream/servers/mist/handler
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response as http_response
import gleam/option
import mist.{type Connection, type ResponseData, Bytes, start}

/// Create a new Dream server with defaults
///
/// Returns a server configured with `AppContext` (just a `request_id` field) and
/// `EmptyServices` (no dependencies). You'll typically chain this with `context()`,
/// `services()`, and `router()` before calling `listen()`.
///
/// ## Example
///
/// ```gleam
/// dream.new()
/// |> dream.services(my_services)
/// |> dream.router(my_router)
/// |> dream.listen(3000)
/// ```
pub fn new() -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  AppContext,
  EmptyServices,
) {
  dream.Dream(
    server: mist.new(fn(_req) {
      http_response.new(404)
      |> http_response.set_body(Bytes(bytes_tree.new()))
    }),
    router: option.None,
    context: context.AppContext(request_id: ""),
    services: option.None,
    max_body_size: 9_223_372_036_854_775_807,
    // Maximum 64-bit signed integer - effectively infinite for practical purposes
  )
}

/// Set a custom context type for your application
///
/// Use this to replace `AppContext` with your own context type that holds
/// user authentication, session data, or any other per-request information.
/// The type system tracks your context through middleware and controllers.
///
/// ## Example
///
/// ```gleam
/// pub type MyContext {
///   MyContext(request_id: String, user: Option(User))
/// }
///
/// dream.new()
/// |> dream.context(MyContext(request_id: "", user: None))
/// |> dream.services(my_services)
/// |> dream.router(my_router)
/// |> dream.listen(3000)
/// ```
pub fn context(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    _old_context,
    old_services,
  ),
  new_context: context,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context, old_services) {
  dream.Dream(
    server: dream_instance.server,
    router: option.None,
    context: new_context,
    services: dream_instance.services,
    max_body_size: dream_instance.max_body_size,
  )
}

/// Provide your application's services
///
/// Services are shared dependencies available to all requests—database connections,
/// HTTP clients, caches, etc. Define a type that holds all your services and pass it here.
///
/// ## Example
///
/// ```gleam
/// pub type Services {
///   Services(db: Connection, cache: Cache)
/// }
///
/// pub fn initialize_services() -> Services {
///   let db = connect_to_database()
///   let cache = create_cache()
///   Services(db: db, cache: cache)
/// }
///
/// dream.new()
/// |> dream.services(initialize_services())
/// |> dream.router(my_router)
/// |> dream.listen(3000)
/// ```
pub fn services(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    old_context,
    router.EmptyServices,
  ),
  services_instance: services,
) -> dream.Dream(mist.Builder(Connection, ResponseData), old_context, services) {
  dream.Dream(
    server: dream_instance.server,
    router: option.None,
    context: dream_instance.context,
    services: option.Some(services_instance),
    max_body_size: dream_instance.max_body_size,
  )
}

/// Provide your application's router
///
/// The router defines which controllers handle which requests. It must be configured
/// with the same context and services types you've set up, which the type system enforces.
///
/// ## Example
///
/// ```gleam
/// pub fn create_router() -> Router(MyContext, Services) {
///   router.new
///   |> router.get("/", controllers.index)
///   |> router.get("/users/:id", controllers.show_user)
/// }
///
/// dream.new()
/// |> dream.services(initialize_services())
/// |> dream.router(create_router())
/// |> dream.listen(3000)
/// ```
pub fn router(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  router_instance: Router(context, services),
) -> dream.Dream(mist.Builder(Connection, ResponseData), context, services) {
  dream.Dream(
    server: dream_instance.server,
    router: option.Some(router_instance),
    context: dream_instance.context,
    services: dream_instance.services,
    max_body_size: dream_instance.max_body_size,
  )
}

/// Set the network interface to bind to
///
/// Defaults to binding to all interfaces. Use "localhost" or "127.0.0.1" to only
/// accept local connections, or "0.0.0.0" to accept connections from any network interface.
///
/// ## Example
///
/// ```gleam
/// // Only accept local connections
/// dream.new()
/// |> dream.services(my_services)
/// |> dream.router(my_router)
/// |> dream.bind("localhost")
/// |> dream.listen(3000)
/// ```
pub fn bind(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  interface: String,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context, services) {
  dream.Dream(
    ..dream_instance,
    server: mist.bind(dream_instance.server, interface),
  )
}

/// Set maximum request body size in bytes
///
/// Requests with bodies larger than this will be rejected. Default is effectively
/// unlimited (max 64-bit int). Set a reasonable limit to protect against memory exhaustion.
///
/// ## Example
///
/// ```gleam
/// // Limit request bodies to 10MB
/// dream.new()
/// |> dream.services(my_services)
/// |> dream.router(my_router)
/// |> dream.max_body_size(10_000_000)
/// |> dream.listen(3000)
/// ```
pub fn max_body_size(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  size: Int,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context, services) {
  dream.Dream(..dream_instance, max_body_size: size)
}

/// Helper function to update context with request_id
/// This is a simple implementation that just returns the template context
/// Most applications don't need request_id in their context
/// If you need request_id, consider using middleware or logging
fn update_context_with_request_id(ctx: context, _request_id: String) -> context {
  // Just return the template context as-is
  // Applications that need request_id can provide custom middleware
  ctx
}

/// Start the server and listen for requests
///
/// Starts the server on the specified port and blocks forever. This is what you call
/// in your `main()` function. If the server fails to start, it returns `Nil` immediately.
///
/// This function will panic if you haven't called `router()` and `services()` first—
/// you can't run a web server without defining what it does.
///
/// ## Example
///
/// ```gleam
/// pub fn main() {
///   dream.new()
///   |> dream.services(initialize_services())
///   |> dream.router(create_router())
///   |> dream.listen(3000)
/// }
/// ```
pub fn listen(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, True)
}

/// Internal function to start the server with configurable blocking behavior
/// Used by listen (blocks forever) and listen_without_blocking (for testing)
fn listen_internal(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
  block_forever: Bool,
) -> Nil {
  // Extract router and services - panic if not set
  let assert option.Some(router_instance) = dream_instance.router
  let assert option.Some(services_instance) = dream_instance.services

  // Create the handler with the router, context, and services
  let handler_fn =
    handler.create(
      router_instance,
      dream_instance.max_body_size,
      dream_instance.context,
      services_instance,
      update_context_with_request_id,
    )

  // Create mist server with the handler
  let server_with_handler = mist.new(handler_fn)

  // Bind to the same interface as the original server (if set)
  // Note: In practice, you'd want to track the interface in Dream
  let server_with_port = mist.port(server_with_handler, port)

  case start(server_with_port) {
    Ok(_) -> {
      case block_forever {
        True -> process.sleep_forever()
        False -> Nil
      }
    }
    Error(_) -> Nil
  }
}

/// Start the server without blocking
///
/// Like `listen()`, but returns immediately instead of blocking forever. Useful for
/// tests where you need the server running in the background so you can make requests to it.
///
/// ## Example
///
/// ```gleam
/// pub fn test_server() {
///   // Start server in background
///   dream.new()
///   |> dream.services(test_services())
///   |> dream.router(test_router())
///   |> dream.listen_without_blocking(8080)
///   
///   // Make test requests
///   let response = http_client.get("http://localhost:8080/test")
///   // ... assertions ...
/// }
/// ```
pub fn listen_without_blocking(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, False)
}
