//// Streaming quick reference: Server-Sent Events
////
//// SSE controllers that use `upgrade_to_sse`, as shown in
//// docs/guides/streaming-quick-reference.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None}

pub type Services {
  Services(events: List(String))
}

pub type EventMessage {
  Publish(data: String)
}

pub fn events(request: Request, _context, services: Services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: services.events,
    on_init: publish_events,
    on_message: send_event,
  )
}

fn publish_events(
  subject: Subject(EventMessage),
  events: List(String),
) -> #(Nil, Option(Selector(EventMessage))) {
  list.each(events, fn(data) { process.send(subject, Publish(data)) })
  #(Nil, None)
}

fn send_event(
  state: Nil,
  message: EventMessage,
  connection: sse.SSEConnection,
  _events: List(String),
) -> sse.Action(Nil, EventMessage) {
  let _ = sse.send_event(connection, sse.event(message.data))
  sse.continue_connection(state)
}

pub type ProgressMessage {
  ProgressUpdate(percent: Int)
}

pub fn long_task(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: start_progress,
    on_message: send_progress,
  )
}

fn start_progress(
  subject: Subject(ProgressMessage),
  _dependencies: Nil,
) -> #(Subject(ProgressMessage), Option(Selector(ProgressMessage))) {
  process.send(subject, ProgressUpdate(0))
  #(subject, None)
}

fn send_progress(
  subject: Subject(ProgressMessage),
  message: ProgressMessage,
  connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Subject(ProgressMessage), ProgressMessage) {
  let _ = sse.send_event(connection, percent_to_event(message.percent))
  case message.percent >= 100 {
    True -> sse.stop_connection()
    False -> {
      process.send(subject, ProgressUpdate(message.percent + 25))
      sse.continue_connection(subject)
    }
  }
}

fn percent_to_event(percent: Int) -> sse.Event {
  sse.event("{\"progress\": " <> int.to_string(percent) <> "}")
}
