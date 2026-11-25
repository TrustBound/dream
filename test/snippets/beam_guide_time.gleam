//// BEAM guide: measure a duration with monotonic time

import gleam/time/duration
import gleam/time/timestamp

/// Wrong: system time is the time of day, and the runtime moves it when
/// the clock of the machine changes, also backwards. A duration from it
/// can be too long, too short or below zero.
pub fn milliseconds_by_clock(work: fn() -> a) -> Int {
  let start = timestamp.system_time()
  let _ = work()
  timestamp.difference(start, timestamp.system_time())
  |> duration.to_milliseconds
}

type TimeUnit {
  Millisecond
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: TimeUnit) -> Int

/// Fix: monotonic time never goes back, so use it for durations
pub fn milliseconds(work: fn() -> a) -> Int {
  let start = monotonic_time(Millisecond)
  let _ = work()
  monotonic_time(Millisecond) - start
}

/// The current monotonic time in milliseconds
pub fn now() -> Int {
  monotonic_time(Millisecond)
}
