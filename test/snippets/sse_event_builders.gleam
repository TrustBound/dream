//// SSE Event Builders
////
//// Example snippet showing how to build SSE events with optional
//// name, id, and retry fields.

import dream/servers/mist/sse

pub fn build_event() -> Result(sse.Event, Nil) {
  let ev =
    sse.event("{\"count\": 1}")
    |> sse.event_name("tick")
    |> sse.event_id("42")
    |> sse.event_retry(5000)

  Ok(ev)
}
