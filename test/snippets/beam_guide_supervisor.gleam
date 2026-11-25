//// BEAM guide: a supervisor starts a new process when one fails

import gleam/erlang/process.{type Name, type Subject}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub type CounterMessage {
  Increment(reply: Subject(Int))
}

/// A counter process, registered under `name`
pub fn start_counter(
  name: Name(CounterMessage),
) -> actor.StartResult(Subject(CounterMessage)) {
  actor.new(0)
  |> actor.named(name)
  |> actor.on_message(fn(count, message) {
    case message {
      Increment(reply) -> {
        process.send(reply, count + 1)
        actor.continue(count + 1)
      }
    }
  })
  |> actor.start
}

/// Starts the counter under a supervisor. When the counter fails, the
/// supervisor starts a new one under the same name.
pub fn start_app(
  name: Name(CounterMessage),
) -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(supervision.worker(fn() { start_counter(name) }))
  |> supervisor.start
}

/// Asks the counter that has the name `name` to count one more
pub fn increment(name: Name(CounterMessage)) -> Int {
  process.call(process.named_subject(name), waiting: 1000, sending: Increment)
}
