//// Server-Sent Events support for Dream (Mist server adapter)
////
//// This module provides Dream's SSE abstraction for the Mist server adapter.
//// It upgrades an HTTP request to an SSE connection backed by a dedicated OTP
//// actor with its own mailbox, avoiding the stalling issues of chunked
//// transfer encoding.
////
//// Most applications will import this module as:
////
//// ```gleam
//// import dream/servers/mist/sse
//// ```
////
//// ## Concepts
////
//// - `SSEConnection` – opaque handle to the SSE connection. Pass it to
////   `send_event` to write events to the client.
//// - `Event` – a structured SSE event with data, optional name, id, and retry.
////   Built with the `event`, `event_name`, `event_id`, and `event_retry`
////   functions.
//// - `Action(state, message)` – the next step in the SSE state machine,
////   returned from your `on_message` handler.
////
//// The typical lifecycle is:
////
//// 1. Router sends a request to a controller.
//// 2. Controller calls `upgrade_to_sse`.
//// 3. Middleware runs on the dummy response (adding CORS, security headers, etc.).
//// 4. The handler performs the actual Mist SSE upgrade, forwarding all
////    middleware-applied headers to the client.
//// 5. `on_init` runs once, receiving a `Subject(message)` that external
////    code can use to send messages into the actor.
//// 6. `on_message` runs for each message received by the actor.
////
//// Handlers follow Dream's "no closures" rule: instead of capturing
//// dependencies, you define a `Dependencies` type and pass it explicitly
//// into `upgrade_to_sse` so every handler receives what it needs.
////
//// ## Example (ticker)
////
//// ```gleam
//// import dream/http/request.{type Request}
//// import dream/http/response.{type Response}
//// import dream/servers/mist/sse
//// import gleam/erlang/process
//// import gleam/int
//// import gleam/option.{None}
////
//// pub type Deps {
////   Deps
//// }
////
//// pub type Tick {
////   Tick
//// }
////
//// pub fn handle_events(request: Request, _context, _services) -> Response {
////   sse.upgrade_to_sse(
////     request,
////     dependencies: Deps,
////     on_init: handle_init,
////     on_message: handle_message,
////   )
//// }
////
//// fn handle_init(
////   subject: process.Subject(Tick),
////   _deps: Deps,
//// ) -> #(Int, option.Option(process.Selector(Tick))) {
////   process.send(subject, Tick)
////   #(0, None)
//// }
////
//// fn handle_message(
////   count: Int,
////   _message: Tick,
////   connection: sse.SSEConnection,
////   _deps: Deps,
//// ) -> sse.Action(Int, Tick) {
////   let event =
////     sse.event(int.to_string(count))
////     |> sse.event_name("tick")
////     |> sse.event_id(int.to_string(count))
////   let _ = sse.send_event(connection, event)
////   process.send_after(process.self_subject(), 1000, Tick)
////   sse.continue_connection(count + 1)
//// }
//// ```

import dream/http/request.{type Request}
import dream/http/response.{type Response, empty_response}
import dream/servers/mist/internal
import gleam/erlang/atom
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string_tree
import mist.{
  type Connection, type ResponseData, type SSEConnection as MistSSEConnection,
}

/// An SSE connection handle.
///
/// This is an opaque type that wraps the underlying server's SSE connection.
/// Pass it to `send_event` to write events to the client.
pub opaque type SSEConnection {
  SSEConnection(internal: MistSSEConnection)
}

/// A structured SSE event.
///
/// Build events with `event`, then optionally add a name, id, or retry
/// interval using the `event_name`, `event_id`, and `event_retry` functions.
///
/// ## Example
///
/// ```gleam
/// sse.event("hello world")
/// |> sse.event_name("greeting")
/// |> sse.event_id("1")
/// |> sse.event_retry(5000)
/// ```
pub opaque type Event {
  Event(internal: mist.SSEEvent)
}

/// The next action to take in the SSE message loop.
pub opaque type Action(state, message) {
  Action(internal: actor.Next(state, message))
}

/// Upgrade an HTTP request to a Server-Sent Events connection.
///
/// This function must be called from within a Dream controller. It defers
/// the actual Mist SSE upgrade until after middleware has run, so any
/// headers added by middleware (CORS, security, etc.) are included in the
/// SSE response sent to the client.
///
/// ## Parameters
///
/// * `request` - The incoming HTTP request
/// * `dependencies` - Application dependencies passed to all handlers
/// * `on_init` - Called once when the actor starts. Receives a
///   `Subject(message)` that external code can send messages to.
///   Returns initial state and an optional selector.
/// * `on_message` - Called for each message the actor receives.
///   Returns the next action.
///
/// ## Example
///
/// ```gleam
/// sse.upgrade_to_sse(
///   request,
///   dependencies: deps,
///   on_init: init_handler,
///   on_message: message_handler,
/// )
///
/// fn init_handler(subject, deps) {
///   process.send(subject, Tick)
///   #(0, None)
/// }
///
/// fn message_handler(state, message, connection, deps) {
///   let _ = sse.send_event(connection, sse.event("ping"))
///   sse.continue_connection(state + 1)
/// }
/// ```
pub fn upgrade_to_sse(
  request _request: Request,
  dependencies dependencies: deps,
  on_init on_init: fn(Subject(message), deps) ->
    #(state, Option(Selector(message))),
  on_message on_message: fn(state, message, SSEConnection, deps) ->
    Action(state, message),
) -> Response {
  let request_key = atom.create(internal.request_key)
  let raw_request = internal.get(request_key)

  let mist_request: http_request.Request(Connection) =
    internal.unsafe_coerce(raw_request)

  let wrapped_init = fn(subj: Subject(message)) {
    let #(state, maybe_selector) = on_init(subj, dependencies)
    let initialised = actor.initialised(state)
    let initialised = case maybe_selector {
      Some(sel) -> actor.selecting(initialised, sel)
      None -> initialised
    }
    Ok(initialised)
  }

  let wrapped_loop = fn(
    state: state,
    message: message,
    mist_conn: MistSSEConnection,
  ) {
    let dream_conn = SSEConnection(internal: mist_conn)
    let Action(next) = on_message(state, message, dream_conn, dependencies)
    next
  }

  let perform_upgrade = fn(headers: List(#(String, String))) {
    let initial_response =
      list.fold(headers, http_response.new(200), fn(resp, h) {
        http_response.set_header(resp, h.0, h.1)
      })
    mist.server_sent_events(
      request: mist_request,
      initial_response: initial_response,
      init: wrapped_init,
      loop: wrapped_loop,
    )
  }

  let upgrade_thunk: Option(
    fn(List(#(String, String))) -> http_response.Response(ResponseData),
  ) = Some(perform_upgrade)

  let upgrade_key = atom.create(internal.upgrade_key)
  internal.put(upgrade_key, internal.unsafe_coerce(upgrade_thunk))

  empty_response(200)
}

/// Send an SSE event to the client.
///
/// ## Example
///
/// ```gleam
/// case sse.send_event(connection, sse.event("hello")) {
///   Ok(Nil) -> sse.continue_connection(state)
///   Error(Nil) -> sse.stop_connection()
/// }
/// ```
pub fn send_event(connection: SSEConnection, event: Event) -> Result(Nil, Nil) {
  let SSEConnection(internal: mist_conn) = connection
  let Event(internal: mist_event) = event
  mist.send_event(mist_conn, mist_event)
}

/// Create an SSE event with the given data string.
///
/// The data is the only required field. Use `event_name`, `event_id`, and
/// `event_retry` to add optional fields.
///
/// ## Example
///
/// ```gleam
/// let ev = sse.event("{\"count\": 42}")
/// ```
pub fn event(data: String) -> Event {
  Event(internal: mist.event(string_tree.from_string(data)))
}

/// Set the event type name.
///
/// Clients can filter on this with `EventSource.addEventListener("name", ...)`.
///
/// ## Example
///
/// ```gleam
/// sse.event("payload")
/// |> sse.event_name("tick")
/// ```
pub fn event_name(event: Event, name: String) -> Event {
  let Event(internal: mist_event) = event
  Event(internal: mist.event_name(mist_event, name))
}

/// Set the event ID.
///
/// The client sends this as `Last-Event-ID` when reconnecting, allowing
/// the server to resume from where it left off.
///
/// ## Example
///
/// ```gleam
/// sse.event("payload")
/// |> sse.event_id("42")
/// ```
pub fn event_id(event: Event, id: String) -> Event {
  let Event(internal: mist_event) = event
  Event(internal: mist.event_id(mist_event, id))
}

/// Set the retry interval in milliseconds.
///
/// This tells the client how long to wait before attempting to reconnect
/// after a connection loss.
///
/// ## Example
///
/// ```gleam
/// sse.event("payload")
/// |> sse.event_retry(5000)
/// ```
pub fn event_retry(event: Event, retry_ms: Int) -> Event {
  let Event(internal: mist_event) = event
  Event(internal: mist.event_retry(mist_event, retry_ms))
}

/// Continue the SSE message loop with the given state.
pub fn continue_connection(state: state) -> Action(state, message) {
  Action(internal: actor.continue(state))
}

/// Continue the SSE message loop with a new selector.
///
/// Use this to change which messages the actor listens for after
/// handling a message.
pub fn continue_connection_with_selector(
  state: state,
  selector: Selector(message),
) -> Action(state, message) {
  Action(internal: actor.continue(state) |> actor.with_selector(selector))
}

/// Stop the SSE message loop normally.
///
/// The actor will shut down and the mist handler will detect the process
/// exit via its monitor.
pub fn stop_connection() -> Action(state, message) {
  Action(internal: actor.stop())
}
