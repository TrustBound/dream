//// Doc comment examples: building events with dream/servers/mist/sse

import dream/servers/mist/sse

pub fn greeting_event() -> sse.Event {
  sse.event("hello world")
  |> sse.event_name("greeting")
  |> sse.event_id("1")
  |> sse.event_retry(5000)
}

pub fn count_event() -> sse.Event {
  let event = sse.event("{\"count\": 42}")
  event
}

pub fn named_event() -> sse.Event {
  sse.event("payload")
  |> sse.event_name("tick")
}

pub fn numbered_event() -> sse.Event {
  sse.event("payload")
  |> sse.event_id("42")
}

pub fn retry_event() -> sse.Event {
  sse.event("payload")
  |> sse.event_retry(5000)
}
