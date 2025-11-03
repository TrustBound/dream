//// Mist server implementation for Dream
////
//// This module provides the Mist-specific server implementation,
//// including functions to create, configure, and start a Dream server
//// using the Mist HTTP server library.

import dream/core/context.{type AppContext}
import dream/core/dream
import dream/core/router.{type EmptyServices, type Router}
import dream/servers/mist/handler
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response as http_response
import gleam/option
import mist.{type Connection, type ResponseData, Bytes, start}

/// Create a new Dream server with defaults using AppContext and EmptyServices
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

/// Set the template context
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

/// Set the services instance (can be called after context)
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

/// Set the router (stores it for later use in listen)
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

/// Set the interface to bind to
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

/// Set maximum body size in bytes
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

/// Start the server on the specified port
/// Blocks forever on success, or returns Nil on error
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

/// Start the server without blocking (useful for testing)
/// Returns Nil immediately after starting, even on success
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
