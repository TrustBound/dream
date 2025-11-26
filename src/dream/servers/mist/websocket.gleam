//// WebSocket support for Dream (Mist server adapter)
////
//// This module provides Dream's WebSocket abstraction for the Mist server
//// adapter. It upgrades an HTTP request to a WebSocket connection and runs
//// a typed message loop driven by your handler functions.
////
//// Most applications will import this module as:
////
//// ```gleam
//// import dream/servers/mist/websocket
//// ```
////
//// ## Concepts
////
//// - `Connection` – opaque handle to the WebSocket. Use it to send messages
////   back to the client.
//// - `Message(custom)` – messages received from the client or from your
////   application via a `Selector(custom)` (text, binary, custom, closed).
//// - `Action(state, custom)` – the next step in the WebSocket state machine,
////   returned from your `on_message` handler.
////
//// The typical lifecycle is:
////
//// 1. Router sends a request to a controller.
//// 2. Controller calls `upgrade_websocket`.
//// 3. `on_init` runs once when the WebSocket is established.
//// 4. `on_message` runs for each incoming or custom message.
//// 5. `on_close` runs after the connection closes.
////
//// Handlers follow Dream's "no closures" rule: instead of capturing
//// dependencies, you define a `Dependencies` type and pass it explicitly
//// into `upgrade_websocket` so every handler receives what it needs.
////
//// ## Example (echo chat)
////
//// ```gleam
//// import dream/http/request.{type Request}
//// import dream/http/response.{type Response, text_response}
//// import dream/http/status
//// import dream/servers/mist/websocket
//// import gleam/erlang/process
//// import gleam/option
////
//// pub type Dependencies {
////   Dependencies(user_name: String)
//// }
////
//// pub fn handle_upgrade(request: Request, context, services) -> Response {
////   let user = request.get_query_param(request.query, "user")
////   let user = option.unwrap(user, "Anonymous")
////   let deps = Dependencies(user_name: user)
////
////   websocket.upgrade_websocket(
////     request,
////     dependencies: deps,
////     on_init: handle_init,
////     on_message: handle_message,
////     on_close: handle_close,
////   )
//// }
////
//// fn handle_init(
////   _connection: websocket.Connection,
////   _deps: Dependencies,
//// ) -> #(String, option.Option(process.Selector(String))) {
////   // Initial state is the username, no extra messages yet
////   #("", option.None)
//// }
////
//// fn handle_message(
////   state: String,
////   message: websocket.Message(String),
////   connection: websocket.Connection,
////   deps: Dependencies,
//// ) -> websocket.Action(String, String) {
////   case message {
////     websocket.TextMessage(text) -> {
////       let reply = deps.user_name <> ": " <> text
////       let _ = websocket.send_text(connection, reply)
////       websocket.continue_connection(state)
////     }
////     websocket.ConnectionClosed -> websocket.stop_connection()
////     _ -> websocket.continue_connection(state)
////   }
//// }
////
//// fn handle_close(_state: String, _deps: Dependencies) -> Nil {
////   Nil
//// }
//// ```

import dream/http/request.{type Request}
import dream/http/response.{type Response, empty_response}
import dream/servers/mist/internal
import gleam/erlang/atom
import gleam/erlang/process.{type Selector}
import gleam/http/request as http_request
import gleam/option.{type Option, Some}
import mist.{type WebsocketConnection, type WebsocketMessage}

/// A WebSocket connection.
///
/// This is an opaque type that wraps the underlying server's connection.
pub opaque type Connection {
  Connection(internal: WebsocketConnection)
}

/// Messages that can be received over a WebSocket connection.
pub type Message(custom) {
  /// A text frame received from the client
  TextMessage(String)
  /// A binary frame received from the client
  BinaryMessage(BitArray)
  /// A custom message from the application (via selector)
  CustomMessage(custom)
  /// The connection was closed
  ConnectionClosed
}

/// Errors that can occur when sending WebSocket messages.
pub type SendError {
  /// The socket is closed or unavailable
  SocketClosed
  /// The send operation timed out
  Timeout
  /// An unknown error occurred
  UnknownError
}

/// The next action to take in the WebSocket loop.
pub opaque type Action(state, custom) {
  Action(internal: mist.Next(state, custom))
}

/// Upgrade an HTTP request to a WebSocket connection.
///
/// This function must be called from within a Dream controller. It handles
/// the protocol upgrade and sets up the WebSocket message loop.
///
/// ## Parameters
///
/// * `request` - The incoming HTTP request
/// * `dependencies` - Application dependencies (services, context, etc.) passed to all handlers
/// * `on_init` - Called when the WebSocket connects. Returns initial state and optional selector.
/// * `on_message` - Called for each WebSocket message. Returns the next action.
/// * `on_close` - Called when the connection closes.
///
/// ## Example
///
/// ```gleam
/// websocket.upgrade_websocket(
///   request,
///   dependencies: services,
///   on_init: init_handler,
///   on_message: message_handler,
///   on_close: close_handler,
/// )
///
/// fn init_handler(connection, services) {
///   #(initial_state, None)
/// }
///
/// fn message_handler(state, message, connection, services) {
///   case message {
///     websocket.TextMessage(text) -> {
///       // Handle text message
///       websocket.continue_connection(state)
///     }
///     websocket.CustomMessage(msg) -> {
///       // Handle custom message from selector
///       websocket.continue_connection(state)
///     }
///     websocket.ConnectionClosed -> websocket.stop_connection()
///     _ -> websocket.continue_connection(state)
///   }
/// }
///
/// fn close_handler(state, services) {
///   Nil
/// }
/// ```
pub fn upgrade_websocket(
  request _request: Request,
  dependencies dependencies: deps,
  on_init on_init: fn(Connection, deps) -> #(state, Option(Selector(custom))),
  on_message on_message: fn(state, Message(custom), Connection, deps) ->
    Action(state, custom),
  on_close on_close: fn(state, deps) -> Nil,
) -> Response {
  // 1. Retrieve stashed Mist request
  let request_key = atom.create(internal.request_key)
  let raw_request = internal.get(request_key)

  // 2. Cast to Mist Request
  let mist_request: http_request.Request(mist.Connection) =
    internal.unsafe_coerce(raw_request)

  // 3. Wrap handlers to convert between Dream and Mist types
  // Note: These closures are necessary to integrate with Mist's API.
  // This is the ONLY place closures are allowed - see standards.md exception.
  let wrapped_on_init = fn(mist_conn: WebsocketConnection) {
    let dream_conn = Connection(internal: mist_conn)
    on_init(dream_conn, dependencies)
  }

  let wrapped_handler = fn(
    state: state,
    mist_msg: WebsocketMessage(custom),
    mist_conn: WebsocketConnection,
  ) {
    let dream_conn = Connection(internal: mist_conn)
    let dream_msg = convert_mist_message_to_dream(mist_msg)
    let Action(mist_action) =
      on_message(state, dream_msg, dream_conn, dependencies)
    mist_action
  }

  let wrapped_on_close = fn(state: state) { on_close(state, dependencies) }

  // 4. Perform upgrade logic
  let mist_response =
    mist.websocket(
      request: mist_request,
      on_init: wrapped_on_init,
      handler: wrapped_handler,
      on_close: wrapped_on_close,
    )

  // 5. Stash the result
  let response_key = atom.create(internal.response_key)
  internal.put(response_key, internal.unsafe_coerce(Some(mist_response)))

  // 6. Return dummy response to satisfy Dream controller signature
  empty_response(200)
}

/// Continue the WebSocket loop with the current state.
pub fn continue_connection(state: state) -> Action(state, custom) {
  Action(internal: mist.continue(state))
}

/// Continue the WebSocket loop with a selector for receiving custom messages.
pub fn continue_connection_with_selector(
  state: state,
  selector: Selector(custom),
) -> Action(state, custom) {
  Action(internal: mist.continue(state) |> mist.with_selector(selector))
}

/// Stop the WebSocket loop normally.
pub fn stop_connection() -> Action(state, custom) {
  Action(internal: mist.stop())
}

/// Send a text frame to the client.
///
/// ## Example
///
/// ```gleam
/// case websocket.send_text(connection, "Hello!") {
///   Ok(Nil) -> // Message sent successfully
///   Error(reason) -> // Handle send error
/// }
/// ```
pub fn send_text(
  connection: Connection,
  message: String,
) -> Result(Nil, SendError) {
  let Connection(internal: mist_conn) = connection
  mist.send_text_frame(mist_conn, message)
  |> convert_socket_error
}

/// Send a binary frame to the client.
///
/// ## Example
///
/// ```gleam
/// case websocket.send_binary(connection, data) {
///   Ok(Nil) -> // Message sent successfully
///   Error(reason) -> // Handle send error
/// }
/// ```
pub fn send_binary(
  connection: Connection,
  message: BitArray,
) -> Result(Nil, SendError) {
  let Connection(internal: mist_conn) = connection
  mist.send_binary_frame(mist_conn, message)
  |> convert_socket_error
}

// ============================================================================
// Internal Conversion
// ============================================================================

fn convert_mist_message_to_dream(
  mist_msg: WebsocketMessage(custom),
) -> Message(custom) {
  case mist_msg {
    mist.Text(text) -> TextMessage(text)
    mist.Binary(data) -> BinaryMessage(data)
    mist.Custom(custom) -> CustomMessage(custom)
    mist.Closed | mist.Shutdown -> ConnectionClosed
  }
}

fn convert_socket_error(result: Result(Nil, a)) -> Result(Nil, SendError) {
  case result {
    Ok(nil) -> Ok(nil)
    Error(_) -> Error(SocketClosed)
  }
}
