//// Events Service - Event broadcasting abstraction
////
//// Provides publish/subscribe for real-time events using BEAM processes.
//// Implementation can be swapped (Redis pubsub, PostgreSQL LISTEN/NOTIFY, etc.)
////
//// Note: This is a simple in-memory broadcaster for demonstration.
//// In production, use a proper message queue or pubsub system.

import gleam/erlang/process
import gleam/yielder
import types/event.{type Event}

/// Events service interface - implementation can be swapped
pub type EventsService {
  EventsService(
    broadcast: fn(Event) -> Nil,
    subscribe: fn() -> yielder.Yielder(Event),
  )
}

/// Initialize events service using simple BEAM process messaging
pub fn init() -> EventsService {
  let broadcast_subject = process.new_subject()
  
  EventsService(
    broadcast: send_event(broadcast_subject, _),
    subscribe: create_subscriber(broadcast_subject),
  )
}

fn send_event(subject: process.Subject(Event), event: Event) -> Nil {
  process.send(subject, event)
}

fn create_subscriber(
  _broadcast_subject: process.Subject(Event),
) -> fn() -> yielder.Yielder(Event) {
  fn() {
    // Create subscriber subject
    let subscriber = process.new_subject()
    
    // Return yielder that waits for events
    yielder.repeatedly(wait_for_event(subscriber))
  }
}

fn wait_for_event(subject: process.Subject(Event)) -> fn() -> Event {
  fn() {
    // Block waiting for next event (60 second timeout)
    let assert Ok(event) = process.receive(subject, 60_000)
    event
  }
}
