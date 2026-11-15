//// SSE guide: broadcasting
////
//// An SSE controller that subscribes to a broadcaster and sends each
//// published event to the client, as shown in docs/guides/sse.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import dream/services/broadcaster
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}

pub type AppEvent {
  AppEvent(text: String)
}

pub type Dependencies {
  Dependencies(event_bus: broadcaster.Broadcaster(AppEvent))
}

pub fn handle_events(
  request: Request,
  _context,
  event_bus: broadcaster.Broadcaster(AppEvent),
) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Dependencies(event_bus: event_bus),
    on_init: handle_init,
    on_message: handle_message,
  )
}

fn handle_init(
  _subject: process.Subject(AppEvent),
  dependencies: Dependencies,
) -> #(Int, option.Option(process.Selector(AppEvent))) {
  let selector =
    broadcaster.subscribe(dependencies.event_bus)
    |> broadcaster.channel_to_selector
  #(0, Some(selector))
}

fn handle_message(
  count: Int,
  message: AppEvent,
  connection: sse.SSEConnection,
  _dependencies: Dependencies,
) -> sse.Action(Int, AppEvent) {
  let AppEvent(text) = message
  let event =
    sse.event(text)
    |> sse.event_id(int.to_string(count))
  case sse.send_event(connection, event) {
    Ok(Nil) -> sse.continue_connection(count + 1)
    Error(Nil) -> sse.stop_connection()
  }
}
