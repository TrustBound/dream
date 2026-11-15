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
import gleam/option.{None}

pub type AppEvent {
  AppEvent(text: String)
}

pub type Dependencies {
  Dependencies(event_bus: broadcaster.Broadcaster(AppEvent))
}

pub type StreamMessage {
  Subscribe
  Published(AppEvent)
}

pub type State {
  State(count: Int, self: process.Subject(StreamMessage))
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
  subject: process.Subject(StreamMessage),
  _dependencies: Dependencies,
) -> #(State, option.Option(process.Selector(StreamMessage))) {
  // Subscribe in on_message: Dream 2.5.0 does not use a selector
  // that on_init returns.
  process.send(subject, Subscribe)
  #(State(count: 0, self: subject), None)
}

fn handle_message(
  state: State,
  message: StreamMessage,
  connection: sse.SSEConnection,
  dependencies: Dependencies,
) -> sse.Action(State, StreamMessage) {
  case message {
    Subscribe -> {
      let selector = subscribe_to_events(state.self, dependencies.event_bus)
      let _ = sse.send_event(connection, sse.event("subscribed"))
      sse.continue_connection_with_selector(state, selector)
    }
    Published(AppEvent(text)) -> {
      let event =
        sse.event(text)
        |> sse.event_id(int.to_string(state.count))
      let _ = sse.send_event(connection, event)
      sse.continue_connection(State(..state, count: state.count + 1))
    }
  }
}

fn subscribe_to_events(
  self: process.Subject(StreamMessage),
  event_bus: broadcaster.Broadcaster(AppEvent),
) -> process.Selector(StreamMessage) {
  let channel = broadcaster.subscribe(event_bus)
  let published =
    broadcaster.channel_to_selector(channel)
    |> process.map_selector(Published)
  // The new selector replaces the old one, so it also selects `self`
  process.new_selector()
  |> process.select(self)
  |> process.merge_selector(published)
}
