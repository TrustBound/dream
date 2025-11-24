//// # Dream Mock Server - Standalone Mode
////
//// Standalone entry point for running the mock server as an application.
////
//// This module provides the main entry point for running the mock server
//// as a standalone application. For programmatic usage in tests, see the `server`
//// module instead.
////
//// ## Usage
////
//// Run the server on port 3004:
////
//// ```sh
//// gleam run -m standalone
//// ```
////
//// The server will start and listen on `http://localhost:3004/`
////
//// ## Available Endpoints
////
//// **Non-streaming endpoints:**
//// - `GET /get` - Returns JSON with request info
//// - `POST /post` - Echoes request body as JSON
//// - `PUT /put` - Echoes request body as JSON
//// - `DELETE /delete` - Returns success response
//// - `GET /json` - Returns simple JSON object
//// - `GET /text` - Returns plain text
//// - `GET /uuid` - Returns UUID-like string
//// - `GET /status/:code` - Returns response with specified status code
////
//// **Streaming endpoints:**
//// - `GET /` - Info page with endpoint documentation
//// - `GET /stream/fast` - 10 chunks at 100ms intervals
//// - `GET /stream/slow` - 5 chunks at 2s intervals
//// - `GET /stream/burst` - 7 chunks with variable timing
//// - `GET /stream/error` - 3 chunks then 500 error
//// - `GET /stream/huge` - 100 chunks for performance testing
//// - `GET /stream/json` - JSON object stream
//// - `GET /stream/binary` - Binary data stream

import dream/servers/mist/server.{bind, listen, router} as dream
import dream_mock_server/router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen(3004)
}
