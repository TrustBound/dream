//// BEAM guide: a test that waits for a message, not for a time

import gleam/erlang/process.{type Subject}

/// Starts a job that makes a thumbnail, and sends its name to `done`
pub fn start_thumbnail(
  image: String,
  make_thumbnail: fn(String) -> String,
  done: Subject(String),
) -> Nil {
  process.spawn(fn() { process.send(done, make_thumbnail(image)) })
  Nil
}

/// Wrong: guesses that 100 milliseconds is enough. On a busy machine it
/// is not, and the test fails at random. On a fast one, it wastes time.
pub fn thumbnail_after_sleep(done: Subject(String)) -> Result(String, Nil) {
  process.sleep(100)
  process.receive(done, within: 0)
}

/// Fix: wait for the message. The test goes on when the job is done, and
/// fails only when the job takes longer than 5 seconds.
pub fn thumbnail_when_done(done: Subject(String)) -> Result(String, Nil) {
  process.receive(done, within: 5000)
}
