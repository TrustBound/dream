import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int
import gleam/option.{None}
import services.{type Services, type TickMessage, Tick}

pub type Dependencies {
  Dependencies(counter_start: Int)
}

pub type State {
  State(count: Int, self: process.Subject(TickMessage))
}

pub fn handle_events(
  request: Request,
  _context,
  _services: Services,
) -> Response {
  let deps = Dependencies(counter_start: 0)

  sse.upgrade_to_sse(
    request,
    dependencies: deps,
    on_init: handle_init,
    on_message: handle_message,
  )
}

pub fn handle_named_events(
  request: Request,
  _context,
  _services: Services,
) -> Response {
  let deps = Dependencies(counter_start: 0)

  sse.upgrade_to_sse(
    request,
    dependencies: deps,
    on_init: handle_init,
    on_message: handle_named_message,
  )
}

fn handle_init(
  subject: process.Subject(TickMessage),
  deps: Dependencies,
) -> #(State, option.Option(process.Selector(TickMessage))) {
  process.send(subject, Tick)
  #(State(count: deps.counter_start, self: subject), None)
}

fn handle_message(
  state: State,
  _message: TickMessage,
  connection: sse.SSEConnection,
  _deps: Dependencies,
) -> sse.Action(State, TickMessage) {
  let ev = sse.event("{\"count\": " <> int.to_string(state.count) <> "}")
  let _ = sse.send_event(connection, ev)

  process.send_after(state.self, 100, Tick)
  sse.continue_connection(State(..state, count: state.count + 1))
}

fn handle_named_message(
  state: State,
  _message: TickMessage,
  connection: sse.SSEConnection,
  _deps: Dependencies,
) -> sse.Action(State, TickMessage) {
  let ev =
    sse.event("{\"count\": " <> int.to_string(state.count) <> "}")
    |> sse.event_name("tick")
    |> sse.event_id(int.to_string(state.count))

  let _ = sse.send_event(connection, ev)

  process.send_after(state.self, 100, Tick)
  sse.continue_connection(State(..state, count: state.count + 1))
}
