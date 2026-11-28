//// SSE guide: a ticker controller
////
//// A controller that upgrades to SSE and sends a "tick" event every second,
//// as shown in docs/guides/sse.md.

import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/http/status
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int
import gleam/option.{None, Some}

pub type Dependencies {
  Dependencies(counter_start: Int)
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  let dependencies = Dependencies(counter_start: 0)

  sse.upgrade_to_sse(
    request,
    dependencies: dependencies,
    on_init: handle_init,
    on_message: handle_message,
  )
}

pub type Tick {
  Tick
}

pub type State {
  State(count: Int, self: process.Subject(Tick))
}

pub fn handle_init(
  subject: process.Subject(Tick),
  dependencies: Dependencies,
) -> #(State, option.Option(process.Selector(Tick))) {
  // Send the first tick to start the loop
  process.send(subject, Tick)
  #(State(count: dependencies.counter_start, self: subject), None)
}

fn handle_message(
  state: State,
  _message: Tick,
  connection: sse.SSEConnection,
  _dependencies: Dependencies,
) -> sse.Action(State, Tick) {
  case sse.send_event(connection, tick_event(state.count)) {
    Ok(Nil) -> {
      // Schedule the next tick
      process.send_after(state.self, 1000, Tick)
      sse.continue_connection(State(..state, count: state.count + 1))
    }
    // The client has gone away, so stop the actor
    Error(Nil) -> sse.stop_connection()
  }
}

pub fn tick_event(count: Int) -> sse.Event {
  sse.event("{\"count\": " <> int.to_string(count) <> "}")
  |> sse.event_name("tick")
  |> sse.event_id(int.to_string(count))
}

pub fn handle_private_events(request: Request, context, services) -> Response {
  // Decide before the upgrade: a refused client gets a normal answer
  case get_header(request.headers, "Authorization") {
    Some("Bearer secret-token") -> handle_events(request, context, services)
    _ -> response.text_response(status.unauthorized, "Unauthorized")
  }
}
