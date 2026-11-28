//// The table of jobs: two ETS tables from `dream_ets`, one for the jobs
//// and one for the next id. The worker writes them, and each request
//// reads them. The process that makes them owns them, so they live as
//// long as that process, also when the worker crashes.

import dream_ets/config
import dream_ets/encoders
import dream_ets/helpers
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom.{type Atom}
import gleam/option.{type Option, None, Some}
import gleam/result

/// The state of a job, as the status route shows it
pub type JobState {
  Queued
  Running
  Done(result: String)
  Failed(reason: String)
  TimedOut
  Lost
  Cancelled
}

pub type Job {
  /// `finished_at` is the monotonic time in milliseconds when the job left
  /// the worker, or `None` while it waits or runs
  Job(id: Int, state: JobState, finished_at: Option(Int))
}

pub opaque type JobTable {
  JobTable(jobs: Table(Int, Job), ids: Table(String, Int))
}

/// Makes the two tables, named after `name`. The process that calls this
/// owns them.
pub fn new(name: String) -> Result(JobTable, EtsError) {
  use jobs <- result.try(
    config.new(name <> "_jobs")
    |> config.key(encoders.int_encoder, encoders.int_decoder())
    |> config.value(encode_job, job_decoder())
    |> config.create,
  )
  use ids <- result.map(helpers.new_counter(name <> "_ids"))
  JobTable(jobs:, ids:)
}

/// The next free id. The ids go up by one and never come back.
pub fn next_id(table: JobTable) -> Result(Int, EtsError) {
  helpers.increment(table.ids, "last_id")
}

/// Adds `job`, or puts it in the place of the job with the same id
pub fn save(table: JobTable, job: Job) -> Result(Nil, EtsError) {
  operations.set(table.jobs, job.id, job)
}

pub fn lookup(table: JobTable, id: Int) -> Result(Option(Job), EtsError) {
  operations.get(table.jobs, id)
}

pub fn list(table: JobTable) -> Result(List(Job), EtsError) {
  operations.values(table.jobs)
}

pub fn delete(table: JobTable, id: Int) -> Result(Nil, EtsError) {
  operations.delete(table.jobs, id)
}

/// The monotonic time in milliseconds. Use it only to measure durations.
pub fn now_milliseconds() -> Int {
  monotonic_time(atom.create("millisecond"))
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: Atom) -> Int

/// The name of `state` in the JSON of the status route
pub fn state_name(state: JobState) -> String {
  case state {
    Queued -> "queued"
    Running -> "running"
    Done(_) -> "done"
    Failed(_) -> "failed"
    TimedOut -> "timed_out"
    Lost -> "lost"
    Cancelled -> "cancelled"
  }
}

fn state_detail(state: JobState) -> String {
  case state {
    Done(result:) -> result
    Failed(reason:) -> reason
    _ -> ""
  }
}

fn parse_state(name: String, detail: String) -> Result(JobState, Nil) {
  case name {
    "queued" -> Ok(Queued)
    "running" -> Ok(Running)
    "done" -> Ok(Done(detail))
    "failed" -> Ok(Failed(detail))
    "timed_out" -> Ok(TimedOut)
    "lost" -> Ok(Lost)
    "cancelled" -> Ok(Cancelled)
    _ -> Error(Nil)
  }
}

fn encode_job(job: Job) -> Dynamic {
  let finished_at = case job.finished_at {
    Some(time) -> dynamic.int(time)
    None -> dynamic.nil()
  }
  dynamic.properties([
    #(dynamic.string("id"), dynamic.int(job.id)),
    #(dynamic.string("state"), dynamic.string(state_name(job.state))),
    #(dynamic.string("detail"), dynamic.string(state_detail(job.state))),
    #(dynamic.string("finished_at"), finished_at),
  ])
}

fn job_decoder() -> Decoder(Job) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("state", decode.string)
  use detail <- decode.field("detail", decode.string)
  use finished_at <- decode.field("finished_at", decode.optional(decode.int))
  case parse_state(name, detail) {
    Ok(state) -> decode.success(Job(id:, state:, finished_at:))
    Error(Nil) ->
      decode.failure(Job(id:, state: Lost, finished_at:), "JobState")
  }
}
