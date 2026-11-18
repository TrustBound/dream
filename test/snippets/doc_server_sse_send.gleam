//// Doc comment example: dream/servers/mist/sse.send_event

import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/option.{type Option, None}

pub type Greet {
  Greet
}

pub fn hello(request, _context, _services) {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: handle_init,
    on_message: handle_message,
  )
}

fn handle_init(
  subject: Subject(Greet),
  _dependencies: Nil,
) -> #(Int, Option(Selector(Greet))) {
  process.send(subject, Greet)
  #(0, None)
}

pub fn handle_message(
  state: Int,
  _message: Greet,
  connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Int, Greet) {
  case sse.send_event(connection, sse.event("hello")) {
    Ok(Nil) -> sse.continue_connection(state)
    Error(Nil) -> sse.stop_connection()
  }
}
