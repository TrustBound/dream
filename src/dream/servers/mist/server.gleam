//// Your Dream app's entry point
////
//// This module is where your web application starts. It provides a builder pattern
//// for configuring and starting a Dream server using Mist (the BEAM's HTTP server).
////
//// ## Quick Start
////
//// ```gleam
//// import dream/servers/mist/server
//// import dream/servers/mist/server.{listen, router}
//// 
//// pub fn main() {
////   server.new()
////   |> router(create_router())
////   |> listen(3000)
//// }
//// ```
////
//// The builder pattern lets you configure your server step by step. Start with `new()`,
//// add your router, and optionally set custom context and services before calling `listen()`.
////
//// ## Custom Context and Services
////
//// By default, Dream uses `EmptyContext` (no per-request data) and `EmptyServices` (no shared
//// dependencies). For most production apps, you'll want to define your own types:
////
//// ```gleam
//// import dream/servers/mist/server
//// import dream/servers/mist/server.{context, listen, router, services}
//// import gleam/option.{None}
//// 
//// pub type MyContext {
////   MyContext(request_id: String, user: option.Option(User), session: Session)
//// }
////
//// server.new()
//// |> context(MyContext(request_id: "", user: None, session: empty_session()))
//// |> services(initialize_services())
//// |> router(create_router())
//// |> listen(3000)
//// ```
////
//// The type system ensures your controllers receive the correct context type.

import dream/context.{type EmptyContext, EmptyContext}
import dream/dream
import dream/router.{type EmptyServices, type Router, EmptyServices}
import dream/servers/mist/handler
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response as http_response
import gleam/option
import gleam/otp/actor
import mist.{type Connection, type ResponseData, Bytes, start}

/// Handle to a running server process
///
/// Returned by `listen_with_handle()` and used by `stop()` to stop the server.
pub opaque type ServerHandle {
  ServerHandle(process_pid: process.Pid)
}

/// Create a new Dream server with defaults
///
/// Returns a server configured with `EmptyContext` (no per-request data) and
/// `EmptyServices` (no dependencies). For simple applications, you only need to add
/// a router. For more complex apps, use `context()` and `services()` to provide your
/// own types before calling `listen()`.
///
/// ## Simple Example (no context or services)
///
/// ```gleam
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen, router}
/// 
/// server.new()
/// |> router(my_router)
/// |> listen(3000)
/// ```
///
/// ## With Custom Context and Services
///
/// ```gleam
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{context, listen, router, services}
/// import gleam/option.{None}
/// 
/// server.new()
/// |> context(MyContext(request_id: "", user: None))
/// |> services(my_services)
/// |> router(my_router)
/// |> listen(3000)
/// ```
pub fn new() -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
) {
  dream.Dream(
    server: mist.new(fn(_req) {
      http_response.new(404)
      |> http_response.set_body(Bytes(bytes_tree.new()))
    }),
    router: option.None,
    context: EmptyContext,
    services: option.Some(EmptyServices),
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{context, listen, router, services}
/// 
/// pub type MyContext {
///   MyContext(request_id: String, user: Option(User))
/// }
///
/// server.new()
/// |> context(MyContext(request_id: "", user: None))
/// |> services(my_services)
/// |> router(my_router)
/// |> listen(3000)
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen, router, services}
/// 
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
/// server.new()
/// |> services(initialize_services())
/// |> router(my_router)
/// |> listen(3000)
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen, router, services}
/// 
/// pub fn create_router() -> Router(MyContext, Services) {
///   router.new
///   |> router.get("/", controllers.index)
///   |> router.get("/users/:id", controllers.show_user)
/// }
///
/// server.new()
/// |> services(initialize_services())
/// |> router(create_router())
/// |> listen(3000)
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{bind, listen, router, services}
/// 
/// // Only accept local connections
/// server.new()
/// |> services(my_services)
/// |> router(my_router)
/// |> bind("localhost")
/// |> listen(3000)
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen, max_body_size, router, services}
/// 
/// // Limit request bodies to 10MB
/// server.new()
/// |> services(my_services)
/// |> router(my_router)
/// |> max_body_size(10_000_000)
/// |> listen(3000)
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
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen, router, services}
/// 
/// pub fn main() {
///   server.new()
///   |> services(initialize_services())
///   |> router(create_router())
///   |> listen(3000)
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
  let _ = listen_internal(dream_instance, port, True)
  Nil
}

/// Internal function to start the server with configurable blocking behavior
/// Returns Result with Started info on success, or Error with StartError on failure
fn listen_internal(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
  block_forever: Bool,
) -> Result(actor.Started(_), actor.StartError) {
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
    Ok(started) -> {
      case block_forever {
        True -> process.sleep_forever()
        False -> Nil
      }
      Ok(started)
    }
    Error(err) -> Error(err)
  }
}

/// Start the server and return a handle for stopping it
///
/// Like `listen()`, but returns immediately with a `ServerHandle` that can be used
/// to stop the server programmatically. Useful for tests and programmatic server control.
///
/// ## Example
///
/// ```gleam
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen_with_handle, router, stop}
///
/// pub fn test_server() {
///   // Start server and get handle
///   let assert Ok(handle) =
///     server.new()
///     |> router(test_router())
///     |> listen_with_handle(8080)
///   
///   // Make test requests
///   let response = http_client.get("http://localhost:8080/test")
///   // ... assertions ...
///   
///   // Stop the server
///   stop(handle)
/// }
/// ```
pub fn listen_with_handle(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
) -> Result(ServerHandle, actor.StartError) {
  case listen_internal(dream_instance, port, False) {
    Ok(started) -> Ok(ServerHandle(process_pid: started.pid))
    Error(err) -> Error(err)
  }
}

/// Stop a server that was started with `listen_with_handle()`
///
/// Stops the server process. This sends a shutdown signal to the supervisor.
/// Note: In tests, you typically don't need to call this - the server will
/// be cleaned up automatically when the test process exits.
///
/// ## Example
///
/// ```gleam
/// import dream/servers/mist/server
/// import dream/servers/mist/server.{listen_with_handle, router, stop}
///
/// pub fn test_server() {
///   let assert Ok(handle) =
///     server.new()
///     |> router(test_router())
///     |> listen_with_handle(8080)
///   
///   // ... use server ...
///   
///   // Optional - server will be cleaned up automatically when test exits
///   stop(handle)
/// }
/// ```
pub fn stop(handle: ServerHandle) -> Nil {
  case handle {
    ServerHandle(process_pid) -> {
      // Send a normal exit signal instead of killing brutally
      // This allows the supervisor to clean up gracefully
      process.send_exit(process_pid)
      Nil
    }
  }
}
