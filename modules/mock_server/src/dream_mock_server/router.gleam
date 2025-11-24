//// router.gleam - Routes for mock server
////
//// Defines both streaming and non-streaming endpoints for testing Dream's HTTP client.
////
//// ## Endpoints
////
//// **Non-streaming:**
//// - `GET /get` - Returns JSON with request info
//// - `POST /post` - Echoes request body as JSON
//// - `PUT /put` - Echoes request body as JSON
//// - `DELETE /delete` - Returns success response
//// - `GET /json` - Returns simple JSON object
//// - `GET /text` - Returns plain text
//// - `GET /uuid` - Returns UUID-like string
//// - `GET /status/:code` - Returns response with specified status code
//// - `GET /large` - Returns ~1MB response (memory testing)
//// - `GET /empty` - Returns empty response body
//// - `GET /slow` - Returns response after 5s delay
////
//// **Streaming:**
//// - `GET /` - Info page
//// - `GET /stream/fast` - 10 chunks @ 100ms
//// - `GET /stream/slow` - 5 chunks @ 2s
//// - `GET /stream/burst` - 7 chunks with variable timing
//// - `GET /stream/error` - 3 chunks then 500 status
//// - `GET /stream/huge` - 100 chunks
//// - `GET /stream/json` - JSON object stream
//// - `GET /stream/binary` - Binary data stream

import dream/context.{type EmptyContext}
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{type EmptyServices, type Router, route, router}
import dream_mock_server/controllers/api_controller
import dream_mock_server/controllers/stream_controller

/// Create a router with all mock endpoints (streaming and non-streaming)
///
/// Returns a router configured with all available mock endpoints for testing
/// HTTP clients. Use this router when starting the server programmatically.
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  // Info page
  |> route(
    method: Get,
    path: "/",
    controller: stream_controller.index,
    middleware: [],
  )
  // Non-streaming endpoints
  |> route(
    method: Get,
    path: "/get",
    controller: api_controller.get,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/post",
    controller: api_controller.post,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/put",
    controller: api_controller.put,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/delete",
    controller: api_controller.delete,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/json",
    controller: api_controller.json_endpoint,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/text",
    controller: api_controller.text,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/uuid",
    controller: api_controller.uuid,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/status/:code",
    controller: api_controller.status,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/large",
    controller: api_controller.large,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/empty",
    controller: api_controller.empty,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/slow",
    controller: api_controller.slow,
    middleware: [],
  )
  // Streaming endpoints
  |> route(
    method: Get,
    path: "/stream/fast",
    controller: stream_controller.stream_fast,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/slow",
    controller: stream_controller.stream_slow,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/burst",
    controller: stream_controller.stream_burst,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/error",
    controller: stream_controller.stream_error,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/huge",
    controller: stream_controller.stream_huge,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/json",
    controller: stream_controller.stream_json,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/binary",
    controller: stream_controller.stream_binary,
    middleware: [],
  )
}
