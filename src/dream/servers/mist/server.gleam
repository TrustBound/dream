//// Your Dream app's entry point
////
//// This module is where your web application starts. It provides a builder pattern
//// for configuring and starting a Dream server using Mist (the BEAM's HTTP server).
////
//// ## Quick Start
////
//// ### Start a server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_quick_start.gleam#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http.{ok, text_response}
//// import dream/http/request.{Get}
//// import dream/router.{route, router}
//// import dream/servers/mist/server
////
//// pub fn main() {
////   server.new()
////   |> server.router(create_router())
////   |> server.listen(3000)
//// }
//// ```
////
//// The builder pattern lets you configure your server step by step. Start with `new()`,
//// optionally set custom context and services, add your router, then call `listen()`.
////
//// ## Builder Order
////
//// Call `context()` and `services()` before `router()`, then `listen()`.
//// `bind()`, `max_body_size()` and `tls()` work at any point before `listen()`.
//// The compiler enforces this order:
////
//// - A router's type includes the context and services types:
////   `Router(context, services)`. `context()` and `services()` change those
////   types, so a router given before them cannot stay in the app. Thus
////   `context()` and `services()` accept only an app that has no router yet
////   (its type ends in `NoRouter`), and calling them after `router()` is a
////   type error.
//// - `listen()` and `listen_with_handle()` accept only an app that has a
////   router (its type ends in `Router(context, services)`), so an app
////   without a router does not compile.
////
//// ## Custom Context and Services
////
//// By default, Dream uses `EmptyContext` (no per-request data) and `EmptyServices` (no shared
//// dependencies). For most production apps, you'll want to define your own types:
////
//// ### Use your own context and services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_custom_context.gleam#L4-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http.{ok, text_response}
//// import dream/http/request.{Get}
//// import dream/router.{type Router, route, router}
//// import dream/servers/mist/server
//// import gleam/option.{None}
////
//// pub type MyContext {
////   MyContext(request_id: String, user: option.Option(User), session: Session)
//// }
////
//// pub fn main() {
////   server.new()
////   |> server.context(MyContext(
////     request_id: "",
////     user: None,
////     session: empty_session(),
////   ))
////   |> server.services(initialize_services())
////   |> server.router(create_router())
////   |> server.listen(3000)
//// }
//// ```
////
//// The type system ensures your controllers receive the correct context type.

import dream/context.{type EmptyContext, EmptyContext}
import dream/dream.{type NoRouter, NoRouter}
import dream/router.{type EmptyServices, type Router, EmptyServices}
import dream/servers/mist/handler
import dream/servers/mist/port_probe
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData, Bytes, start}
import simplifile

/// Handle to a running server process
///
/// Returned by `listen_with_handle()` and used by `stop()` to stop the server.
pub opaque type ServerHandle {
  ServerHandle(process_pid: process.Pid)
}

/// Create a new Dream server with defaults
///
/// Returns a server configured with `EmptyContext` (no per-request data),
/// `EmptyServices` (no dependencies) and no router (`NoRouter`). For simple
/// applications, you only need to add a router. For more complex apps, use
/// `context()` and `services()` to provide your own types before you call
/// `router()`.
///
/// ## Simple Example (no context or services)
///
/// ### Serve a router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_new.gleam#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{route, router}
/// import dream/servers/mist/server
///
/// pub fn main() {
///   server.new()
///   |> server.router(my_router())
///   |> server.listen(3000)
/// }
/// ```
///
/// ## With Custom Context and Services
///
/// ### Add context and services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_new_with_context.gleam#L4-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{type Router, route, router}
/// import dream/servers/mist/server
/// import gleam/option.{None}
///
/// pub fn main() {
///   server.new()
///   |> server.context(MyContext(request_id: "", user: None))
///   |> server.services(my_services())
///   |> server.router(my_router())
///   |> server.listen(3000)
/// }
/// ```
pub fn new() -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  EmptyContext,
  EmptyServices,
  NoRouter,
) {
  dream.create(
    server: mist.new(fn(_request) {
      http_response.new(404)
      |> http_response.set_body(Bytes(bytes_tree.new()))
    }),
    router: NoRouter,
    context: EmptyContext,
    services: EmptyServices,
    // Sensible default for buffered bodies: 10MB
    max_body_size: 10_000_000,
    bind_interface: option.None,
  )
}

/// Set a custom context type for your application
///
/// Use this to replace the default `EmptyContext` with your own context type that holds
/// user authentication, session data, or any other per-request information.
/// The type system tracks your context through middleware and controllers.
///
/// Call `context()` before `router()`. A router's type includes the context
/// type, so `context()` accepts only an app that has no router yet. Calling it
/// after `router()` is a compile error.
///
/// ## Example
///
/// ### Set a custom context <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_context.gleam#L3-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{type Router, route, router}
/// import dream/servers/mist/server
/// import gleam/option.{type Option, None}
///
/// pub type MyContext {
///   MyContext(request_id: String, user: Option(User))
/// }
///
/// pub fn main() {
///   server.new()
///   |> server.context(MyContext(request_id: "", user: None))
///   |> server.services(my_services())
///   |> server.router(my_router())
///   |> server.listen(3000)
/// }
/// ```
pub fn context(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    _old_context,
    services,
    NoRouter,
  ),
  new_context: context,
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  NoRouter,
) {
  dream.create(
    server: dream.get_server(dream_instance, risks_understood: True),
    router: NoRouter,
    context: new_context,
    services: dream.get_services(dream_instance),
    max_body_size: dream.get_max_body_size(dream_instance),
    bind_interface: dream.get_bind_interface(dream_instance),
  )
  |> dream.set_tls(dream.get_tls(dream_instance))
}

/// Provide your application's services
///
/// Services are shared dependencies available to all requests—database connections,
/// HTTP clients, caches, etc. Define a type that holds all your services and pass it here.
///
/// Call `services()` before `router()`. A router's type includes the services
/// type, so `services()` accepts only an app that has no router yet. Calling it
/// after `router()` is a compile error.
///
/// ## Example
///
/// ### Provide services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_services.gleam#L3-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{type Router, route, router}
/// import dream/servers/mist/server
///
/// pub type Services {
///   Services(database: Connection, cache: Cache)
/// }
///
/// pub fn initialize_services() -> Services {
///   let database = connect_to_database()
///   let cache = create_cache()
///   Services(database: database, cache: cache)
/// }
///
/// pub fn main() {
///   server.new()
///   |> server.services(initialize_services())
///   |> server.router(my_router())
///   |> server.listen(3000)
/// }
/// ```
pub fn services(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    EmptyServices,
    NoRouter,
  ),
  services_instance: services,
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  NoRouter,
) {
  dream.create(
    server: dream.get_server(dream_instance, risks_understood: True),
    router: NoRouter,
    context: dream.get_context(dream_instance),
    services: services_instance,
    max_body_size: dream.get_max_body_size(dream_instance),
    bind_interface: dream.get_bind_interface(dream_instance),
  )
  |> dream.set_tls(dream.get_tls(dream_instance))
}

/// Provide your application's router
///
/// The router defines which controllers handle which requests. It must be configured
/// with the same context and services types you've set up, which the type system enforces.
///
/// Call `router()` once, after `context()` and `services()`. It accepts only
/// an app that has no router yet (`NoRouter`), and returns an app whose type
/// holds the `Router(context, services)`. Only that app can `listen()`.
///
/// ## Example
///
/// ### Provide a router <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_router.gleam#L3-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{type Request, Get, get_string_param}
/// import dream/router.{type Router, route, router}
/// import dream/servers/mist/server
///
/// pub fn create_router() -> Router(MyContext, Services) {
///   router()
///   |> route(method: Get, path: "/", controller: index, middleware: [])
///   |> route(
///     method: Get,
///     path: "/users/:id",
///     controller: show_user,
///     middleware: [],
///   )
/// }
///
/// pub fn main() {
///   server.new()
///   |> server.context(MyContext(request_id: ""))
///   |> server.services(initialize_services())
///   |> server.router(create_router())
///   |> server.listen(3000)
/// }
/// ```
pub fn router(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    NoRouter,
  ),
  router_instance: Router(context, services),
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  Router(context, services),
) {
  dream.create(
    server: dream.get_server(dream_instance, risks_understood: True),
    router: router_instance,
    context: dream.get_context(dream_instance),
    services: dream.get_services(dream_instance),
    max_body_size: dream.get_max_body_size(dream_instance),
    bind_interface: dream.get_bind_interface(dream_instance),
  )
  |> dream.set_tls(dream.get_tls(dream_instance))
}

/// Set the network interface to bind to
///
/// Defaults to binding to all interfaces. Use "localhost" or "127.0.0.1" to only
/// accept local connections, or "0.0.0.0" to accept connections from any network interface.
///
/// ## Example
///
/// ### Accept local connections only <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_bind.gleam#L3-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{route, router}
/// import dream/servers/mist/server
///
/// pub fn main() {
///   // Only accept local connections
///   server.new()
///   |> server.services(my_services())
///   |> server.router(my_router())
///   |> server.bind("localhost")
///   |> server.listen(3000)
/// }
/// ```
pub fn bind(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    router_state,
  ),
  interface: String,
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  router_state,
) {
  dream.create(
    server: mist.bind(
      dream.get_server(dream_instance, risks_understood: True),
      interface,
    ),
    router: dream.get_router(dream_instance),
    context: dream.get_context(dream_instance),
    services: dream.get_services(dream_instance),
    max_body_size: dream.get_max_body_size(dream_instance),
    bind_interface: option.Some(interface),
  )
  |> dream.set_tls(dream.get_tls(dream_instance))
}

/// Set maximum request body size in bytes
///
/// Requests with bodies larger than this will be rejected. The default is
/// 10_000_000 bytes (10MB), which is a safe limit for typical JSON and form
/// payloads. Streaming routes are not affected by this limit.
///
/// ## Example
///
/// ### Limit the body size <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_max_body_size.gleam#L3-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{bad_request, ok, text_response}
/// import dream/http/request.{type Request, Post, body_as_string}
/// import dream/router.{route, router}
/// import dream/servers/mist/server
///
/// pub fn main() {
///   // Limit request bodies to 10MB
///   server.new()
///   |> server.services(my_services())
///   |> server.router(my_router())
///   |> server.max_body_size(10_000_000)
///   |> server.listen(3000)
/// }
/// ```
pub fn max_body_size(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    router_state,
  ),
  size: Int,
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  router_state,
) {
  dream.create(
    server: dream.get_server(dream_instance, risks_understood: True),
    router: dream.get_router(dream_instance),
    context: dream.get_context(dream_instance),
    services: dream.get_services(dream_instance),
    max_body_size: size,
    bind_interface: dream.get_bind_interface(dream_instance),
  )
  |> dream.set_tls(dream.get_tls(dream_instance))
}

/// Serve HTTPS with a certificate and key
///
/// Both arguments are paths to PEM files. Over HTTPS, clients and the server
/// agree on HTTP/2 during the TLS handshake (ALPN), and clients that do not
/// ask for HTTP/2 get HTTP/1.1. Browsers use HTTP/2 only over HTTPS.
///
/// Without `tls()`, the server serves plain HTTP: HTTP/1.1, and HTTP/2 for
/// clients that send it from the start (prior knowledge).
///
/// If a file does not exist, `listen()` panics and `listen_with_handle()`
/// returns an error.
///
/// ### Serve HTTPS <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/server_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{route, router}
/// import dream/servers/mist/server
///
/// fn index(_request, _context, _services) {
///   text_response(ok, "Hello over HTTPS")
/// }
///
/// pub fn start(certfile: String, keyfile: String, port: Int) {
///   server.new()
///   |> server.router(
///     router()
///     |> route(method: Get, path: "/", controller: index, middleware: []),
///   )
///   |> server.tls(certfile:, keyfile:)
///   |> server.listen_with_handle(port)
/// }
/// ```
pub fn tls(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    router_state,
  ),
  certfile certfile: String,
  keyfile keyfile: String,
) -> dream.Dream(
  mist.Builder(Connection, ResponseData),
  context,
  services,
  router_state,
) {
  dream.set_tls(
    dream_instance,
    option.Some(dream.Tls(certfile: certfile, keyfile: keyfile)),
  )
}

/// Start the server and listen for requests
///
/// Starts the server on the specified port and blocks forever. This is what you call
/// in your `main()` function. If the server fails to start, it panics with the reason.
///
/// `listen()` accepts only an app that has a router: an app without a call to
/// `router()` does not compile. `services()` is optional: the default services
/// are `EmptyServices`.
///
/// ## Example
///
/// ### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_listen.gleam#L3-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{type Router, route, router}
/// import dream/servers/mist/server
///
/// pub fn main() {
///   server.new()
///   |> server.services(initialize_services())
///   |> server.router(create_router())
///   |> server.listen(3000)
/// }
/// ```
pub fn listen(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, True)
  |> panic_on_start_error
}

/// Start the server and return a handle for stopping it
///
/// Like `listen()`, but returns immediately with a `ServerHandle` that can be used
/// to stop the server programmatically. Useful for tests and programmatic server control.
/// Like `listen()`, it accepts only an app that has a router.
///
/// ## Example
///
/// ### Start and stop a test server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_listen_with_handle.gleam#L3-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{Get}
/// import dream/http/response.{text_response}
/// import dream/http/status
/// import dream/router.{route, router}
/// import dream/servers/mist/server
/// import dream_http_client/client
/// import gleam/http
///
/// pub fn test_server(port: Int) -> Result(String, String) {
///   // Start server and get handle
///   let started =
///     server.new()
///     |> server.router(test_router())
///     |> server.listen_with_handle(port)
///
///   case started {
///     Ok(handle) -> {
///       // Make test requests
///       let response =
///         client.new()
///         |> client.scheme(http.Http)
///         |> client.host("localhost")
///         |> client.port(port)
///         |> client.path("/test")
///         |> client.send()
///
///       // Stop the server
///       server.stop(handle)
///       response_body(response)
///     }
///     Error(_start_error) -> Error("server did not start")
///   }
/// }
/// ```
pub fn listen_with_handle(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
  port: Int,
) -> Result(ServerHandle, actor.StartError) {
  case listen_internal(dream_instance, port, False) {
    Ok(started) -> Ok(ServerHandle(process_pid: started.pid))
    Error(error) -> Error(error)
  }
}

/// Stop a server that was started with `listen_with_handle()`
///
/// Stops the server and returns when it is down, so the port is free for a new
/// server when `stop` returns. You can call it from any process, not only from
/// the process that started the server.
///
/// The server supervisor stops each of its children with the shutdown time that
/// the child specification gives, then exits with reason `normal`. The process
/// that started the server keeps running. A request that is in progress when
/// `stop` is called does not get a response: its connection closes.
///
/// `stop` is idempotent. If the server is already down, `stop` returns `Nil`
/// and does not crash the caller.
///
/// Note: In tests, you typically don't need to call this - the server will
/// be cleaned up automatically when the test process exits.
///
/// ## Example
///
/// ### Stop a server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_stop.gleam#L3-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http.{ok, text_response}
/// import dream/http/request.{Get}
/// import dream/router.{route, router}
/// import dream/servers/mist/server
/// import gleam/otp/actor
/// import gleam/result
///
/// pub fn test_server(port: Int) -> Result(Nil, actor.StartError) {
///   let started =
///     server.new()
///     |> server.router(test_router())
///     |> server.listen_with_handle(port)
///
///   // ... use server ...
///
///   // Optional - server will be cleaned up automatically when test exits
///   result.map(started, server.stop)
/// }
/// ```
pub fn stop(handle: ServerHandle) -> Nil {
  case handle {
    ServerHandle(process_pid) -> stop_supervisor(process_pid)
  }
}

/// Stops the supervisor with `gen_server:stop/1` and waits until it is down.
/// See `dream_mist_server_ffi.erl` for why this works from any process.
@external(erlang, "dream_mist_server_ffi", "stop_supervisor")
fn stop_supervisor(supervisor_pid: process.Pid) -> Nil

/// Helper function to update context with request_id
/// This is a simple implementation that just returns the template context
/// Most applications don't need request_id in their context
/// If you need request_id, consider using middleware or logging
fn update_context_with_request_id(
  template_context: context,
  _request_id: String,
) -> context {
  // Just return the template context as-is
  // Applications that need request_id can provide custom middleware
  template_context
}

fn bind_label(interface: option.Option(String)) -> String {
  option.unwrap(interface, "localhost")
}

fn port_in_use_error(port: Int, bind_label: String) -> actor.StartError {
  let message =
    "Port "
    <> int.to_string(port)
    <> " already in use on "
    <> bind_label
    <> ". Stop the process using that port or choose a different one."
  actor.InitFailed(message)
}

fn build_handler(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
) -> fn(http_request.Request(Connection)) ->
  http_response.Response(ResponseData) {
  handler.create(
    dream.get_router(dream_instance),
    dream.get_max_body_size(dream_instance),
    dream.get_context(dream_instance),
    dream.get_services(dream_instance),
    update_context_with_request_id,
  )
}

fn build_server(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    router_state,
  ),
  handler_function: fn(http_request.Request(Connection)) ->
    http_response.Response(ResponseData),
  port: Int,
) -> mist.Builder(Connection, ResponseData) {
  let server_with_handler = mist.new(handler_function)
  let server_with_interface = case dream.get_bind_interface(dream_instance) {
    option.Some(interface) -> mist.bind(server_with_handler, interface)
    option.None -> server_with_handler
  }
  let server_with_tls = case dream.get_tls(dream_instance) {
    option.Some(dream.Tls(certfile:, keyfile:)) ->
      mist.with_tls(server_with_interface, certfile:, keyfile:)
    option.None -> server_with_interface
  }
  mist.port(server_with_tls, port)
}

fn check_tls_files(
  tls: option.Option(dream.Tls),
) -> Result(Nil, actor.StartError) {
  case tls {
    option.None -> Ok(Nil)
    option.Some(dream.Tls(certfile:, keyfile:)) ->
      [certfile, keyfile]
      |> list.find(fn(path) { simplifile.is_file(path) != Ok(True) })
      |> result.map(fn(path) {
        actor.InitFailed("TLS file not found: " <> path)
      })
      |> result.map(Error)
      |> result.unwrap(Ok(Nil))
  }
}

fn handle_blocking(block_forever: Bool) -> Nil {
  case block_forever {
    True -> process.sleep_forever()
    False -> Nil
  }
}

fn start_server(
  server_with_port: mist.Builder(Connection, ResponseData),
  block_forever: Bool,
) -> Result(actor.Started(_), actor.StartError) {
  start(server_with_port)
  |> result.map(fn(started) {
    handle_blocking(block_forever)
    started
  })
}

fn panic_on_start_error(result: Result(a, actor.StartError)) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(actor.InitFailed(message)) -> panic as message
    Error(error) -> {
      let message = "Failed to start server: " <> string.inspect(error)
      panic as message
    }
  }
}

/// Internal function to start the server with configurable blocking behavior
/// Returns Result with Started info on success, or Error with StartError on failure
fn listen_internal(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
  port: Int,
  block_forever: Bool,
) -> Result(actor.Started(_), actor.StartError) {
  let bind_interface = dream.get_bind_interface(dream_instance)
  let bind_interface_label = bind_label(bind_interface)

  use Nil <- result.try(check_tls_files(dream.get_tls(dream_instance)))
  case port_probe.is_in_use(bind_interface, port) {
    True -> Error(port_in_use_error(port, bind_interface_label))
    False -> {
      let handler_function = build_handler(dream_instance)
      let server_with_port =
        build_server(dream_instance, handler_function, port)

      start_server(server_with_port, block_forever)
    }
  }
}
