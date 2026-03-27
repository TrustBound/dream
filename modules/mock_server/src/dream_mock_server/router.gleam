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
//// - `POST /content-type` - Echoes request Content-Type as plain text
//// - `GET /json` - Returns simple JSON object
//// - `GET /text` - Returns plain text
//// - `GET /uuid` - Returns UUID-like string
//// - `GET /status/:code` - Returns response with specified status code
//// - `GET /large` - Returns ~1MB response (memory testing)
//// - `GET /empty` - Returns empty response body
//// - `GET /slow` - Returns response after 5s delay
////
//// **Redirect:**
//// - `GET /redirect/301` - 301 redirect to /text
//// - `GET /redirect/302` - 302 redirect to /text
//// - `GET /redirect/303` - 303 redirect to /text (forces GET)
//// - `GET /redirect/307` - 307 redirect to /text (preserves method)
//// - `GET /redirect/308` - 308 redirect to /text (preserves method, permanent)
//// - `GET /redirect/chain` - 302 chain: /chain -> /chain/2 -> /text
//// - `GET /redirect/absolute` - 302 with fully-qualified Location URL
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
import dream/http/request.{Delete, Get, Patch, Post, Put}
import dream/router.{type EmptyServices, type Router, route, router}
import dream_mock_server/config.{type MockConfigContext}
import dream_mock_server/controllers/api_controller
import dream_mock_server/controllers/config_controller
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
    method: Post,
    path: "/content-type",
    controller: api_controller.content_type,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/put",
    controller: api_controller.put,
    middleware: [],
  )
  |> route(
    method: Patch,
    path: "/patch",
    controller: api_controller.patch,
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
  // Compression endpoints
  |> route(
    method: Get,
    path: "/gzip",
    controller: api_controller.gzip,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/deflate",
    controller: api_controller.deflate,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/identity",
    controller: api_controller.identity,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/unknown-encoding",
    controller: api_controller.unknown_encoding,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/corrupted-gzip",
    controller: api_controller.corrupted_gzip,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/echo-accept-encoding",
    controller: api_controller.echo_accept_encoding,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/non-utf8-error",
    controller: api_controller.non_utf8_error,
    middleware: [],
  )
  // Redirect endpoints
  |> route(
    method: Get,
    path: "/redirect/301",
    controller: api_controller.redirect_301,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/302",
    controller: api_controller.redirect_302,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/303",
    controller: api_controller.redirect_303,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/307",
    controller: api_controller.redirect_307,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/308",
    controller: api_controller.redirect_308,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/chain",
    controller: api_controller.redirect_chain,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/chain/2",
    controller: api_controller.redirect_chain_2,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/redirect/absolute",
    controller: api_controller.redirect_absolute,
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
    path: "/stream/drop",
    controller: stream_controller.stream_drop,
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
  // Compressed streaming endpoints
  |> route(
    method: Get,
    path: "/stream/gzip",
    controller: stream_controller.stream_gzip,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/deflate",
    controller: stream_controller.stream_deflate,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/stream/unknown-encoding",
    controller: stream_controller.stream_unknown_encoding,
    middleware: [],
  )
}

/// Create a router for config mode: a single catch-all route per method
/// that delegates to the config controller. Used when starting with
/// `server.start_with_config(port, config)`.
///
/// This router intentionally contains no built-in demo endpoints. All response
/// behavior comes from the caller-provided `MockRoute` list held in context.
pub fn create_config_router() -> Router(MockConfigContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/**path",
    controller: config_controller.handle,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/**path",
    controller: config_controller.handle,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/**path",
    controller: config_controller.handle,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/**path",
    controller: config_controller.handle,
    middleware: [],
  )
  |> route(
    method: Patch,
    path: "/**path",
    controller: config_controller.handle,
    middleware: [],
  )
}
