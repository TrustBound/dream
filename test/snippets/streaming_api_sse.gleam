//// Streaming API reference: Server-Sent Events
////
//// A controller that upgrades to SSE and sends two named events. The actor
//// stops when an event cannot be sent because the client has gone.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int
import gleam/option.{None}

pub type Message {
  Tick
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: fn(subject, _dependencies) {
      process.send(subject, Tick)
      process.send(subject, Tick)
      #(0, None)
    },
    on_message: fn(count, _message, connection, _dependencies) {
      send_tick(connection, count)
    },
  )
}

fn send_tick(
  connection: sse.SSEConnection,
  count: Int,
) -> sse.Action(Int, Message) {
  case sse.send_event(connection, create_tick_event(count)) {
    Ok(Nil) -> sse.continue_connection(count + 1)
    Error(Nil) -> sse.stop_connection()
  }
}

pub fn create_tick_event(count: Int) -> sse.Event {
  let count_text = int.to_string(count)
  sse.event("{\"count\": " <> count_text <> "}")
  |> sse.event_name("tick")
  |> sse.event_id(count_text)
  |> sse.event_retry(5000)
}
