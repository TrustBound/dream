//// Streaming guide: Server-Sent Events
////
//// SSE controllers that use `upgrade_to_sse`, as shown in
//// docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import gleam/erlang/process.{type Selector, type Subject}
import gleam/int
import gleam/option.{type Option, None}

pub type Message {
  Tick
}

pub fn handle_events(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: fn(subject, _dependencies) {
      process.send(subject, Tick)
      #(0, None)
    },
    on_message: fn(count, _message, connection, _dependencies) {
      let _ = sse.send_event(connection, sse.event("ping"))
      sse.continue_connection(count + 1)
    },
  )
}

pub type ProgressMessage {
  ProgressUpdate(percent: Int)
}

pub fn long_running_task(request: Request, _context, _services) -> Response {
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
  let _ = sse.send_event(connection, progress_to_event(message.percent))
  continue_until_done(subject, message.percent)
}

fn continue_until_done(
  subject: Subject(ProgressMessage),
  percent: Int,
) -> sse.Action(Subject(ProgressMessage), ProgressMessage) {
  case percent >= 100 {
    True -> sse.stop_connection()
    False -> {
      process.send(subject, ProgressUpdate(percent + 25))
      sse.continue_connection(subject)
    }
  }
}

fn progress_to_event(percent: Int) -> sse.Event {
  sse.event("{\"progress\": " <> int.to_string(percent) <> "}")
}
