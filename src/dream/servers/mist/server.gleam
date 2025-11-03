//// Mist server implementation for Dream
////
//// This module provides the Mist-specific server implementation,
//// including functions to create, configure, and start a Dream server
//// using the Mist HTTP server library.

import dream/core/context.{type AppContext}
import dream/core/dream
import dream/core/router.{type Router, router as default_router}
import dream/servers/mist/handler
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response as http_response
import mist.{type Connection, type ResponseData, Bytes, start}

/// Create a new Dream server with defaults using AppContext
pub fn new() -> dream.Dream(mist.Builder(Connection, ResponseData), AppContext) {
  dream.Dream(
    server: mist.new(fn(_req) {
      http_response.new(404)
      |> http_response.set_body(Bytes(bytes_tree.new()))
    }),
    router: default_router,
    max_body_size: 9_223_372_036_854_775_807,
    // Maximum 64-bit signed integer - effectively infinite for practical purposes
  )
}

/// Set the router (recreates handler with new router)
pub fn router(
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), _),
  router: Router(context),
  create_context: fn(String) -> context,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context) {
  dream.Dream(
    router: router,
    max_body_size: dream_instance.max_body_size,
    server: mist.new(handler.create(
      router,
      dream_instance.max_body_size,
      create_context,
    )),
  )
}

/// Set the interface to bind to
pub fn bind(
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), context),
  interface: String,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context) {
  dream.Dream(
    ..dream_instance,
    server: mist.bind(dream_instance.server, interface),
  )
}

/// Set maximum body size in bytes
pub fn max_body_size(
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), context),
  size: Int,
  create_context: fn(String) -> context,
) -> dream.Dream(mist.Builder(Connection, ResponseData), context) {
  dream.Dream(
    ..dream_instance,
    max_body_size: size,
    server: mist.new(handler.create(dream_instance.router, size, create_context)),
  )
}

/// Start the server on the specified port
/// Blocks forever on success, or returns Nil on error
pub fn listen(
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), context),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, True)
}

/// Internal function to start the server with configurable blocking behavior
/// Used by listen (blocks forever) and listen_without_blocking (for testing)
fn listen_internal(
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), context),
  port: Int,
  block_forever: Bool,
) -> Nil {
  let server_with_port = mist.port(dream_instance.server, port)
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
  dream_instance: dream.Dream(mist.Builder(Connection, ResponseData), context),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, False)
}
