//// WebSocket support for Dream (Mist server adapter)
////
//// Guide: [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html).
////
//// This module provides Dream's WebSocket abstraction for the Mist server
//// adapter. It upgrades an HTTP request to a WebSocket connection and runs
//// a typed message loop driven by your handler functions.
////
//// Most applications will import this module as:
////
//// ### Import the module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_chat.gleam#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
////   application via a `Selector(custom)` (text, binary, custom).
////   A close is not a message: `on_close` runs for it.
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
//// ### Echo chat <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_chat.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/http/request.{type Request, get_query_param}
//// import dream/http/response.{type Response}
//// import dream/servers/mist/websocket
//// import gleam/erlang/process
//// import gleam/option
////
//// pub type Dependencies {
////   Dependencies(user_name: String)
//// }
////
//// pub fn handle_upgrade(request: Request, _context, _services) -> Response {
////   let user = get_query_param(request.query, "user")
////   let user = option.unwrap(user, "Anonymous")
////   let dependencies = Dependencies(user_name: user)
////
////   websocket.upgrade_websocket(
////     request,
////     dependencies: dependencies,
////     on_init: handle_init,
////     on_message: handle_message,
////     on_close: handle_close,
////   )
//// }
////
//// fn handle_init(
////   _connection: websocket.Connection,
////   _dependencies: Dependencies,
//// ) -> #(String, option.Option(process.Selector(String))) {
////   // Initial state is an empty string, no extra messages yet
////   #("", option.None)
//// }
////
//// fn handle_message(
////   state: String,
////   message: websocket.Message(String),
////   connection: websocket.Connection,
////   dependencies: Dependencies,
//// ) -> websocket.Action(String, String) {
////   case message {
////     websocket.TextMessage(text) -> {
////       let reply = dependencies.user_name <> ": " <> text
////       let _ = websocket.send_text(connection, reply)
////       websocket.continue_connection(state)
////     }
////     _ -> websocket.continue_connection(state)
////   }
//// }
////
//// fn handle_close(_state: String, _dependencies: Dependencies) -> Nil {
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
///
/// A close is not a message: when the connection closes, `on_close` runs.
pub type Message(custom) {
  /// A text frame received from the client
  TextMessage(String)
  /// A binary frame received from the client
  BinaryMessage(BitArray)
  /// A custom message from the application (via selector)
  CustomMessage(custom)
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
/// ### Upgrade to a WebSocket <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_upgrade.gleam#L6-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn connect(request, _context, services) {
///   websocket.upgrade_websocket(
///     request,
///     dependencies: services,
///     on_init: init_handler,
///     on_message: message_handler,
///     on_close: close_handler,
///   )
/// }
///
/// fn init_handler(_connection, _services) {
///   #(0, None)
/// }
///
/// fn message_handler(state, message, connection, _services) {
///   case message {
///     websocket.TextMessage(text) -> {
///       // Handle text message
///       let _ = websocket.send_text(connection, text)
///       websocket.continue_connection(state + 1)
///     }
///     websocket.CustomMessage(custom_message) -> {
///       // Handle custom message from selector
///       let _ = websocket.send_text(connection, custom_message)
///       websocket.continue_connection(state)
///     }
///     _ -> websocket.continue_connection(state)
///   }
/// }
///
/// fn close_handler(_state, _services) {
///   Nil
/// }
/// ```
///
/// Guide: [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html).
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
  let wrapped_on_init = fn(mist_connection: WebsocketConnection) {
    let dream_connection = Connection(internal: mist_connection)
    on_init(dream_connection, dependencies)
  }

  let wrapped_handler = fn(
    state: state,
    mist_message: WebsocketMessage(custom),
    mist_connection: WebsocketConnection,
  ) {
    let dream_connection = Connection(internal: mist_connection)
    let dream_message = convert_mist_message_to_dream(mist_message)
    let Action(mist_action) =
      on_message(state, dream_message, dream_connection, dependencies)
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
///
/// ## Example
///
/// ### Keep the socket open <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_upgrade.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/websocket
/// import gleam/option.{None}
///
/// pub fn connect(request, _context, services) {
///   websocket.upgrade_websocket(
///     request,
///     dependencies: services,
///     on_init: init_handler,
///     on_message: message_handler,
///     on_close: close_handler,
///   )
/// }
///
/// fn init_handler(_connection, _services) {
///   #(0, None)
/// }
///
/// fn message_handler(state, message, connection, _services) {
///   case message {
///     websocket.TextMessage(text) -> {
///       // Handle text message
///       let _ = websocket.send_text(connection, text)
///       websocket.continue_connection(state + 1)
///     }
///     websocket.CustomMessage(custom_message) -> {
///       // Handle custom message from selector
///       let _ = websocket.send_text(connection, custom_message)
///       websocket.continue_connection(state)
///     }
///     _ -> websocket.continue_connection(state)
///   }
/// }
///
/// fn close_handler(_state, _services) {
///   Nil
/// }
/// ```
pub fn continue_connection(state: state) -> Action(state, custom) {
  Action(internal: mist.continue(state))
}

/// Continue the WebSocket loop with a selector for receiving custom messages.
///
/// ## Example
///
/// ### Listen to a new subject <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_selector.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request}
/// import dream/http/response.{type Response}
/// import dream/servers/mist/websocket
/// import gleam/erlang/process.{type Selector}
/// import gleam/option.{type Option, None}
///
/// pub fn notifications(request: Request, _context, _services) -> Response {
///   websocket.upgrade_websocket(
///     request,
///     dependencies: Nil,
///     on_init: start,
///     on_message: handle_message,
///     on_close: close,
///   )
/// }
///
/// fn start(
///   _connection: websocket.Connection,
///   _dependencies: Nil,
/// ) -> #(Nil, Option(Selector(String))) {
///   #(Nil, None)
/// }
///
/// fn handle_message(
///   state: Nil,
///   message: websocket.Message(String),
///   connection: websocket.Connection,
///   _dependencies: Nil,
/// ) -> websocket.Action(Nil, String) {
///   case message {
///     websocket.TextMessage("subscribe") -> subscribe(state)
///     websocket.CustomMessage(text) -> forward(state, connection, text)
///     _ -> websocket.continue_connection(state)
///   }
/// }
///
/// fn subscribe(state: Nil) -> websocket.Action(Nil, String) {
///   let notifications = process.new_subject()
///   process.send(notifications, "You are subscribed")
///   // From now on the loop also receives the messages sent to notifications
///   let selector =
///     process.new_selector()
///     |> process.select(notifications)
///   websocket.continue_connection_with_selector(state, selector)
/// }
///
/// fn forward(
///   state: Nil,
///   connection: websocket.Connection,
///   text: String,
/// ) -> websocket.Action(Nil, String) {
///   case websocket.send_text(connection, text) {
///     Ok(Nil) -> websocket.continue_connection(state)
///     Error(_send_error) -> websocket.stop_connection()
///   }
/// }
///
/// fn close(_state: Nil, _dependencies: Nil) -> Nil {
///   Nil
/// }
/// ```
pub fn continue_connection_with_selector(
  state: state,
  selector: Selector(custom),
) -> Action(state, custom) {
  Action(internal: mist.continue(state) |> mist.with_selector(selector))
}

/// Stop the WebSocket loop normally.
///
/// ## Example
///
/// ### Close the socket <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_stop.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/http/request.{type Request}
/// import dream/http/response.{type Response}
/// import dream/servers/mist/websocket
/// import gleam/erlang/process.{type Selector}
/// import gleam/option.{type Option, None}
///
/// pub fn conversation(request: Request, _context, _services) -> Response {
///   websocket.upgrade_websocket(
///     request,
///     dependencies: Nil,
///     on_init: start,
///     on_message: handle_message,
///     on_close: close,
///   )
/// }
///
/// fn start(
///   _connection: websocket.Connection,
///   _dependencies: Nil,
/// ) -> #(Nil, Option(Selector(Nil))) {
///   #(Nil, None)
/// }
///
/// fn handle_message(
///   state: Nil,
///   message: websocket.Message(Nil),
///   _connection: websocket.Connection,
///   _dependencies: Nil,
/// ) -> websocket.Action(Nil, Nil) {
///   case message {
///     // The client sent "bye": stop the loop, and the server closes the socket
///     websocket.TextMessage("bye") -> websocket.stop_connection()
///     _ -> websocket.continue_connection(state)
///   }
/// }
///
/// fn close(_state: Nil, _dependencies: Nil) -> Nil {
///   Nil
/// }
/// ```
pub fn stop_connection() -> Action(state, custom) {
  Action(internal: mist.stop())
}

/// Send a text frame to the client.
///
/// ## Example
///
/// ### Send text <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_send.gleam#L9-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn send_greeting(
///   state: Nil,
///   connection: websocket.Connection,
/// ) -> websocket.Action(Nil, Nil) {
///   case websocket.send_text(connection, "Hello!") {
///     Ok(Nil) -> websocket.continue_connection(state)
///     Error(_reason) -> websocket.stop_connection()
///   }
/// }
/// ```
pub fn send_text(
  connection: Connection,
  message: String,
) -> Result(Nil, SendError) {
  let Connection(internal: mist_connection) = connection
  mist.send_text_frame(mist_connection, message)
  |> convert_socket_error
}

/// Send a binary frame to the client.
///
/// ## Example
///
/// ### Send binary data <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_websocket_send.gleam#L19-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn send_data(
///   state: Nil,
///   connection: websocket.Connection,
///   data: BitArray,
/// ) -> websocket.Action(Nil, Nil) {
///   case websocket.send_binary(connection, data) {
///     Ok(Nil) -> websocket.continue_connection(state)
///     Error(_reason) -> websocket.stop_connection()
///   }
/// }
/// ```
pub fn send_binary(
  connection: Connection,
  message: BitArray,
) -> Result(Nil, SendError) {
  let Connection(internal: mist_connection) = connection
  mist.send_binary_frame(mist_connection, message)
  |> convert_socket_error
}

// ============================================================================
// Internal Conversion
// ============================================================================

fn convert_mist_message_to_dream(
  mist_message: WebsocketMessage(custom),
) -> Message(custom) {
  case mist_message {
    mist.Text(text) -> TextMessage(text)
    mist.Binary(data) -> BinaryMessage(data)
    mist.Custom(custom) -> CustomMessage(custom)
  }
}

fn convert_socket_error(result: Result(Nil, a)) -> Result(Nil, SendError) {
  case result {
    Ok(nil) -> Ok(nil)
    Error(_) -> Error(SocketClosed)
  }
}
