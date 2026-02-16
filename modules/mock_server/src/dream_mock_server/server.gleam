//// # Programmatic Server Control
////
//// This module provides functions to start and stop the mock server
//// programmatically. This is useful for integration tests where you need
//// complete control over the server lifecycle.
////
//// ## Usage in Tests
////
//// ```gleam
//// import dream_mock_server/server
//// import gleam/http/request
//// import gleam/httpc
////
//// pub fn my_streaming_test() {
////   // Start the mock server
////   let assert Ok(handle) = server.start(3004)
////   
////   // Make HTTP requests to localhost:3004
////   let assert Ok(response) = 
////     request.to("http://localhost:3004/stream/fast")
////     |> httpc.send
////   
////   // Stop the server
////   server.stop(handle)
//// }
//// ```
////
//// ## Available Endpoints
////
//// **Non-streaming endpoints:**
//// - `GET /` - Info page listing all endpoints
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
//// **Streaming endpoints:**
//// - `GET /stream/fast` - 10 chunks @ 100ms intervals
//// - `GET /stream/slow` - 5 chunks @ 2s intervals
//// - `GET /stream/burst` - 7 chunks with variable timing
//// - `GET /stream/error` - 3 chunks then 500 status
//// - `GET /stream/huge` - 100 chunks @ 10ms intervals
//// - `GET /stream/json` - JSON object stream
//// - `GET /stream/binary` - Binary data stream

import dream/servers/mist/server.{bind, context, listen_with_handle, router} as dream_server
import dream_mock_server/config.{type MockRoute, MockConfigContext}
import dream_mock_server/router.{create_config_router, create_router}
import gleam/otp/actor

/// Start the mock server on a specific port
///
/// Returns a `ServerHandle` that can be used to stop the server later.
/// The port must be explicitly provided - there is no default.
///
/// ## Example
///
/// ```gleam
/// import dream_mock_server/server
///
/// let assert Ok(handle) = server.start(3004)
/// // ... make HTTP requests to localhost:3004 ...
/// server.stop(handle)
/// ```
///
/// ## Errors
///
/// Returns an error if the server fails to start, typically due to:
/// - **Port already in use** - Another process is bound to the port
/// - **Insufficient permissions** - Port < 1024 requires root on Unix systems
/// - **System resource limits** - OS limits on open files/sockets reached
///
/// ### Port Conflicts
///
/// If the port is already in use, the OTP supervisor will crash with
/// `Eaddrinuse`. This is **expected OTP behavior** for startup errors - port
/// conflicts are configuration problems that should fail loudly and immediately.
/// Ensure ports are available before starting the server, or catch the supervisor
/// crash at the deployment level if needed.
pub fn start(port: Int) -> Result(dream_server.ServerHandle, actor.StartError) {
  dream_server.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen_with_handle(port)
}

/// Start the mock server with caller-provided routes.
///
/// In this mode, the server uses only the supplied config list and does not
/// expose the built-in demo endpoints from `start(port)`.
///
/// ## Matching semantics
///
/// - Routes are evaluated in list order.
/// - First matching route wins.
/// - A route matches when both are true:
///   - Path matches according to `path_match` (`Exact` or `Prefix`)
///   - Method matches (`Some(method)`) or the route method is `None`
/// - If no route matches, response is `404` with body `"Not found"`.
///
/// Returns a `ServerHandle` that can be used to stop the server later.
///
/// ## Example
///
/// ```gleam
/// import dream_mock_server/config.{MockRoute, Prefix}
/// import dream_mock_server/server
/// import gleam/option.{None}
///
/// let config = [
///   MockRoute("/v1/chat/completions", Prefix, None, 200, "{\"ok\":true}"),
/// ]
/// let assert Ok(handle) = server.start_with_config(3004, config)
/// // ... make requests to localhost:3004 ...
/// server.stop(handle)
/// ```
///
/// ## Typical use cases
///
/// - Deterministic proxy/adaptor tests
/// - Verifying status and payload handling branches
/// - Simulating external API behavior without provider-specific stubs
pub fn start_with_config(
  port: Int,
  config: List(MockRoute),
) -> Result(dream_server.ServerHandle, actor.StartError) {
  dream_server.new()
  |> context(MockConfigContext(routes: config))
  |> router(create_config_router())
  |> bind("localhost")
  |> listen_with_handle(port)
}

/// Stop the mock server
///
/// Gracefully stops the server using the provided handle. This function
/// is idempotent - calling it multiple times with the same handle is safe.
///
/// ## Example
///
/// ```gleam
/// import dream_mock_server/server
///
/// let assert Ok(handle) = server.start(3004)
/// // ... do work ...
/// server.stop(handle)
/// ```
pub fn stop(handle: dream_server.ServerHandle) -> Nil {
  dream_server.stop(handle)
}
