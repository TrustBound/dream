//// router.gleam - Routes for streaming example
////
//// This router demonstrates both streaming and non-streaming HTTP client usage.

import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import examples/streaming/controllers/stream_controller

/// Create a router with streaming examples
pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  |> route(
    method: Get,
    path: "/",
    handler: stream_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream",
    handler: stream_controller.show,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/fetch",
    handler: stream_controller.new,
    middleware: [],
  )
}
