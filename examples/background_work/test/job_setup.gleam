//// What the job tests need: settings with a job that the test controls,
//// the log lines as messages, and waits with a limit. No test sleeps.

import app.{type App}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/result
import job_worker.{type Settings, Settings}
import report

/// A job that runs: the test lets it finish or crash. `job` is the
/// process of the job.
pub type Gate {
  Gate(input: String, job: Pid, release: Subject(Release))
}

pub type Release {
  Finish
  Crash
}

/// The settings of a test app. Each job waits for the test, and each log
/// line comes to `lines`. The cleanup interval is one hour, so a test
/// that does not set a shorter one never sees a cleanup.
pub fn test_settings(gates: Subject(Gate), lines: Subject(String)) -> Settings {
  Settings(
    run_job: gated_job(gates, _),
    max_queued: 10,
    job_timeout: 5000,
    cleanup_interval: 3_600_000,
    log: process.send(lines, _),
  )
}

/// Runs in the process of the job: tells the test that the job runs, and
/// waits until the test lets it finish or crash
fn gated_job(gates: Subject(Gate), input: String) -> String {
  let release = process.new_subject()
  process.send(gates, Gate(input:, job: process.self(), release:))
  case process.receive_forever(release) {
    Finish -> report.summarise(input)
    Crash -> panic as "the job crashed"
  }
}

/// Starts the app with `settings` and tables named after `name`, runs
/// `body`, and stops the app. Each test gives its own name.
pub fn with_app(
  name: String,
  settings: Settings,
  body: fn(App) -> Result(a, String),
) -> Result(a, String) {
  use started <- result.try(app.start("test_" <> name, settings))
  let result = body(started)
  app.stop(started)
  result
}

/// Waits at most 5 seconds for the next job that runs
pub fn wait_for_gate(gates: Subject(Gate)) -> Result(Gate, String) {
  process.receive(gates, within: 5000)
  |> result.replace_error("No job started in 5 seconds")
}

/// Waits at most 5 seconds for the log line `expected`, and gives it with
/// `log: ` in front. Fails on another line, so the order of the lines is
/// part of the test.
pub fn wait_for_line(
  lines: Subject(String),
  expected: String,
) -> Result(String, String) {
  case process.receive(lines, within: 5000) {
    Ok(line) if line == expected -> Ok("log: " <> line)
    Ok(line) ->
      Error(
        "Expected the log line \"" <> expected <> "\", got \"" <> line <> "\"",
      )
    Error(Nil) -> Error("No log line \"" <> expected <> "\" in 5 seconds")
  }
}

/// Watches the process of a job, so a test can wait for its end
pub fn watch(gate: Gate) -> process.Monitor {
  process.monitor(gate.job)
}

/// Waits at most 5 seconds for the end of the watched process, and gives
/// the reason
pub fn wait_for_end(
  monitor: process.Monitor,
) -> Result(process.ExitReason, String) {
  process.new_selector()
  |> process.select_specific_monitor(monitor, fn(down) { down.reason })
  |> process.selector_receive(within: 5000)
  |> result.replace_error("The job process did not end in 5 seconds")
}

/// The number of messages that wait in the mailbox of `pid`
pub fn mailbox_size(pid: Pid) -> Int {
  let #(_item, size) = process_info(pid, atom.create("message_queue_len"))
  size
}

@external(erlang, "erlang", "process_info")
fn process_info(pid: Pid, item: Atom) -> #(Atom, Int)
