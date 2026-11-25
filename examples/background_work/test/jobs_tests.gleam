//// The job app of the guide "Run background work": each test starts its
//// own app, and compares what happens with an output of the guide.

import app_request.{get, post_job}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context.{before_each, describe, it}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import job_setup.{
  type Gate, Crash, Finish, mailbox_size, test_settings, wait_for_end,
  wait_for_gate, wait_for_line, watch, with_app,
}
import job_worker.{Settings}
import report
import simplifile

/// The subjects of one test. `before_each` makes them in the process of
/// the test, so only that test receives from them.
pub type Probes {
  Probes(gates: Subject(Gate), lines: Subject(String))
}

fn new_probes() -> Probes {
  Probes(gates: process.new_subject(), lines: process.new_subject())
}

pub fn tests() -> TestSuite {
  describe("Background jobs", context.value(new_probes()), [
    before_each(fn(_probes) { Ok(new_probes()) }),
    it("answers 202 at once, then the status shows the result", accepts_job),
    it("answers 503 when the queue is full", rejects_job_when_full),
    it("marks a crashed job failed and runs the next job", fails_crashed_job),
    it("marks the jobs of a killed worker lost", restarts_worker),
    it("stops a job at its timeout and runs the next job", times_out_job),
    it("removes finished jobs on the cleanup timer", cleans_up),
    it("lets the running job finish when it stops", stops_cleanly),
    it("answers 404 for a job that does not exist", fn(probes: Probes) {
      use started <- with_app(
        "missing",
        test_settings(probes.gates, probes.lines),
      )

      let response = get(started.services, "/jobs/99")

      response
      |> should
      |> be_equal("GET /jobs/99\n  404 {\"error\":\"No job 99\"}")
      |> or_fail_with("GET /jobs/99 should answer 404")
    }),
    it("answers 400 for an id that is not a number", fn(probes: Probes) {
      use started <- with_app(
        "bad_id",
        test_settings(probes.gates, probes.lines),
      )

      let response = get(started.services, "/jobs/first")

      response
      |> should
      |> be_equal(
        "GET /jobs/first\n  400 {\"error\":\"The id must be a number\"}",
      )
      |> or_fail_with("GET /jobs/first should answer 400")
    }),
    it("counts the words and lines of the input", fn(_probes: Probes) {
      let input = "sales by region\ncosts by team"

      let summary = report.summarise(input)

      summary
      |> should
      |> be_equal("words: 6, lines: 2")
      |> or_fail_with("the summary should count 6 words on 2 lines")
    }),
  ])
}

fn accepts_job(probes: Probes) -> Result(AssertionResult, String) {
  use started <- with_app("accepted", test_settings(probes.gates, probes.lines))
  let services = started.services
  use worker_started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))

  let accepted = post_job(services, "sales by region and team")
  use job_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  let running = get(services, "/jobs/1")
  use gate <- result.try(wait_for_gate(probes.gates))
  process.send(gate.release, Finish)
  use job_done <- result.try(wait_for_line(probes.lines, "job 1 done"))
  let done = get(services, "/jobs/1")

  [worker_started, accepted, job_started, running, job_done, done]
  |> match_output("job_accepted")
}

fn rejects_job_when_full(probes: Probes) -> Result(AssertionResult, String) {
  let settings =
    Settings(..test_settings(probes.gates, probes.lines), max_queued: 2)
  use started <- with_app("queue_full", settings)
  let services = started.services

  let first = post_job(services, "first")
  let second = post_job(services, "second")
  let third = post_job(services, "third")
  let fourth = post_job(services, "fourth")
  let waiting = get(services, "/jobs/3")

  [first, second, third, fourth, waiting]
  |> match_output("queue_full")
}

fn fails_crashed_job(probes: Probes) -> Result(AssertionResult, String) {
  use started <- with_app(
    "job_crash",
    test_settings(probes.gates, probes.lines),
  )
  let services = started.services
  use _started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))
  let first = post_job(services, "first")
  let second = post_job(services, "second")
  use first_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  use first_gate <- result.try(wait_for_gate(probes.gates))

  process.send(first_gate.release, Crash)
  use failed <- result.try(wait_for_line(probes.lines, "job 1 failed"))
  use second_started <- result.try(wait_for_line(probes.lines, "job 2 started"))
  let states = [get(services, "/jobs/1"), get(services, "/jobs/2")]

  [first, second, first_started, "(the test makes job 1 crash)", failed]
  |> list.append([second_started, ..states])
  |> match_output("job_crash")
}

fn restarts_worker(probes: Probes) -> Result(AssertionResult, String) {
  use started <- with_app(
    "worker_crash",
    test_settings(probes.gates, probes.lines),
  )
  let services = started.services
  use _started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))
  let first = post_job(services, "first")
  let second = post_job(services, "second")
  let third = post_job(services, "third")
  use _job_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  use gate <- result.try(wait_for_gate(probes.gates))
  let job = watch(gate)
  use worker <- result.try(
    process.subject_owner(services.worker)
    |> result.replace_error("No job worker runs"),
  )

  process.kill(worker)
  use restarted <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 3)",
  ))
  let lost = [
    get(services, "/jobs/1"),
    get(services, "/jobs/2"),
    get(services, "/jobs/3"),
  ]
  let fourth = post_job(services, "fourth")
  use fourth_started <- result.try(wait_for_line(probes.lines, "job 4 started"))
  // The job process of job 1 was linked to the old worker
  use job_end <- result.try(wait_for_end(job))
  let old_job = get(services, "/jobs/1")

  [[first, second, third, "(the test kills the worker)", restarted], lost]
  |> list.flatten
  |> list.append([
    fourth,
    fourth_started,
    "the process of job 1 ended: " <> string.inspect(job_end),
    old_job,
  ])
  |> match_output("worker_crash")
}

fn times_out_job(probes: Probes) -> Result(AssertionResult, String) {
  let settings =
    Settings(..test_settings(probes.gates, probes.lines), job_timeout: 300)
  use started <- with_app("timeout", settings)
  let services = started.services
  use _started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))
  let first = post_job(services, "first")
  let second = post_job(services, "second")
  use first_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  use first_gate <- result.try(wait_for_gate(probes.gates))
  let first_job = watch(first_gate)

  // The test never lets job 1 finish
  use timed_out <- result.try(wait_for_line(probes.lines, "job 1 timed_out"))
  use second_started <- result.try(wait_for_line(probes.lines, "job 2 started"))
  use second_gate <- result.try(wait_for_gate(probes.gates))
  let second_job = watch(second_gate)
  process.send(second_gate.release, Finish)
  use second_done <- result.try(wait_for_line(probes.lines, "job 2 done"))
  let states = [get(services, "/jobs/1"), get(services, "/jobs/2")]
  use first_end <- result.try(wait_for_end(first_job))
  use second_end <- result.try(wait_for_end(second_job))
  // A call goes after the exit messages of both jobs in the mailbox
  let third = post_job(services, "third")
  use worker <- result.try(
    process.subject_owner(services.worker)
    |> result.replace_error("No job worker runs"),
  )
  let mailbox = mailbox_size(worker)

  [first, second, first_started, timed_out, second_started, second_done]
  |> list.append(states)
  |> list.append([
    "the process of job 1 ended: " <> string.inspect(first_end),
    "the process of job 2 ended: " <> string.inspect(second_end),
    third,
    "messages in the worker mailbox: " <> int.to_string(mailbox),
  ])
  |> match_output("job_timeout")
}

fn cleans_up(probes: Probes) -> Result(AssertionResult, String) {
  let settings =
    Settings(..test_settings(probes.gates, probes.lines), cleanup_interval: 200)
  use started <- with_app("cleanup", settings)
  let services = started.services
  use _started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))
  let accepted = post_job(services, "first")
  use _job_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  use gate <- result.try(wait_for_gate(probes.gates))
  process.send(gate.release, Finish)
  use job_done <- result.try(wait_for_line(probes.lines, "job 1 done"))
  let done = get(services, "/jobs/1")

  use removed <- result.try(wait_for_line(
    probes.lines,
    "removed finished jobs: 1",
  ))
  let gone = get(services, "/jobs/1")

  [accepted, job_done, done, removed, gone]
  |> match_output("cleanup")
}

fn stops_cleanly(probes: Probes) -> Result(AssertionResult, String) {
  use started <- with_app("stop", test_settings(probes.gates, probes.lines))
  let services = started.services
  use _started <- result.try(wait_for_line(
    probes.lines,
    "the job worker started (lost jobs: 0)",
  ))
  let first = post_job(services, "first")
  let second = post_job(services, "second")
  use _job_started <- result.try(wait_for_line(probes.lines, "job 1 started"))
  use gate <- result.try(wait_for_gate(probes.gates))

  let stopped = process.new_subject()
  process.spawn(fn() {
    process.send(stopped, job_worker.stop(services.worker, within: 5000))
  })
  use stopping <- result.try(wait_for_line(
    probes.lines,
    "stopping after job 1 ends",
  ))
  let third = post_job(services, "third")
  process.send(gate.release, Finish)
  use job_done <- result.try(wait_for_line(probes.lines, "job 1 done"))
  use worker_stopped <- result.try(wait_for_line(
    probes.lines,
    "the job worker stopped (cancelled jobs: 1)",
  ))
  use stop_result <- result.try(
    process.receive(stopped, within: 5000)
    |> result.replace_error("stop did not return in 5 seconds"),
  )
  let states = [get(services, "/jobs/1"), get(services, "/jobs/2")]
  let fourth = post_job(services, "fourth")

  let stop_returned = "stop returned " <> string.inspect(stop_result)
  [
    [
      first,
      second,
      "(the test calls stop with a limit of 5000 ms)",
      stopping,
      third,
      job_done,
    ],
    [worker_stopped, stop_returned],
    states,
    [fourth],
  ]
  |> list.flatten
  |> match_output("clean_stop")
}

/// Compares the lines with `test/outputs/<name>.txt`
fn match_output(
  lines: List(String),
  name: String,
) -> Result(AssertionResult, String) {
  let actual = string.join(lines, "\n") <> "\n"
  use expected <- result.try(
    simplifile.read("test/outputs/" <> name <> ".txt")
    |> result.map_error(simplifile.describe_error),
  )
  actual
  |> should
  |> be_equal(expected)
  |> or_fail_with("the lines should match test/outputs/" <> name <> ".txt")
}
