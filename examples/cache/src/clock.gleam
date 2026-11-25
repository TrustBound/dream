//// The time that the app reads. The running app reads the clock of the
//// computer. A test gives the app a fixed time, so that it can move time
//// forward without a sleep.

import gleam/time/timestamp.{type Timestamp}

pub type Clock {
  /// The time of the computer
  SystemClock
  /// Always the same time. A test makes a new clock to move time forward.
  FixedClock(time: Timestamp)
}

/// The current time of `clock`
pub fn read_time(clock: Clock) -> Timestamp {
  case clock {
    SystemClock -> timestamp.system_time()
    FixedClock(time:) -> time
  }
}
