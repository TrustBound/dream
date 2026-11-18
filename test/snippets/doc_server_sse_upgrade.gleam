//// Doc comment example: dream/servers/mist/sse.upgrade_to_sse

import dream/servers/mist/sse
import gleam/erlang/process
import gleam/option.{None}

pub type Tick {
  Tick
}

pub fn events(request, _context, services) {
  sse.upgrade_to_sse(
    request,
    dependencies: services,
    on_init: init_handler,
    on_message: message_handler,
  )
}

fn init_handler(subject, _services) {
  process.send(subject, Tick)
  #(0, None)
}

fn message_handler(state, _message, connection, _services) {
  let _ = sse.send_event(connection, sse.event("ping"))
  sse.continue_connection(state + 1)
}
