//// router.gleam - Routes for streaming example
////
//// This router demonstrates both streaming and non-streaming HTTP client usage.

import controllers/stream_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}

/// Create a router with streaming examples
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/",
    controller: stream_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream",
    controller: stream_controller.show,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/fetch",
    controller: stream_controller.new,
    middleware: [],
  )
}
