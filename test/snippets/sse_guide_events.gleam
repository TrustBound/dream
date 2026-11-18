//// SSE guide: event builders
////
//// Builds SSE events and sends them, as shown in docs/guides/sse.md.

import dream/servers/mist/sse

pub fn build_minimal_event() -> sse.Event {
  // Minimal event (data only)
  sse.event("hello world")
}

pub fn build_full_event() -> sse.Event {
  // Event with all optional fields
  sse.event("{\"count\": 42}")
  // event: tick
  |> sse.event_name("tick")
  // id: 42
  |> sse.event_id("42")
  // retry: 5000
  |> sse.event_retry(5000)
}

pub fn send_event_or_stop(
  state: state,
  connection: sse.SSEConnection,
  event: sse.Event,
) -> sse.Action(state, message) {
  case sse.send_event(connection, event) {
    Ok(Nil) -> sse.continue_connection(state)
    Error(Nil) -> sse.stop_connection()
  }
}
