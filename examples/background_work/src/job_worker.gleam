//// The job worker: one actor that takes jobs, keeps them in a queue with a
//// limit, runs each job in a linked process with a timeout, and cleans up
//// finished jobs on a timer. The state of each job is in the job table,
//// so a request reads it without a call to the worker.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{
  type ExitMessage, type ExitReason, type Name, type Pid, type Subject,
  type Timer, Abnormal, ExitMessage, Killed, Normal,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/supervision.{type ChildSpecification}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import job_table.{
  type Job, type JobState, type JobTable, Cancelled, Done, Failed, Job, Lost,
  Queued, Running, TimedOut,
}

pub type Settings {
  Settings(
    /// The work of one job: it gets the input and gives the result
    run_job: fn(String) -> String,
    /// How many jobs can wait while one job runs
    max_queued: Int,
    /// How long one job can run, in milliseconds
    job_timeout: Int,
    /// How often the worker removes finished jobs, in milliseconds. A
    /// finished job stays at least this long.
    cleanup_interval: Int,
    /// Where the worker writes what it does
    log: fn(String) -> Nil,
  )
}

pub type Message {
  Submit(input: String, reply: Subject(Result(Int, SubmitError)))
  Stop(reply: Subject(Nil))
  JobFinished(id: Int, result: String)
  JobExited(exit: ExitMessage)
  JobTimedOut(id: Int)
  CleanUp
}

pub type SubmitError {
  /// `max_queued` jobs wait already
  QueueFull
  /// The worker stops after the job that runs now
  Stopping
  /// The worker did not answer in time, or it does not run
  NoAnswer
  /// The job table did not take the job
  NotSaved(reason: String)
}

type RunningJob {
  RunningJob(id: Int, pid: Pid, timer: Timer)
}

type State {
  State(
    settings: Settings,
    table: JobTable,
    /// The subject of the messages from the worker's own jobs and timers.
    /// Only this process of the worker receives from it.
    own: Subject(Message),
    /// The jobs that wait, oldest first. At most `max_queued` of them.
    queue: List(#(Int, String)),
    queued: Int,
    running: Option(RunningJob),
    /// The callers of `stop` that wait for the running job to finish
    stop_replies: List(Subject(Nil)),
    /// The jobs that ended, and whose exit message did not come yet
    ended_jobs: Set(Pid),
  )
}

/// The child specification of the worker for a supervisor. `Transient`:
/// the supervisor starts the worker again after a crash, and not after
/// `stop`.
pub fn supervised(
  name: Name(Message),
  table: JobTable,
  settings: Settings,
) -> ChildSpecification(Subject(Message)) {
  supervision.worker(fn() { start(name, table, settings) })
  |> supervision.restart(supervision.Transient)
}

/// Starts the worker, registered under `name`
pub fn start(
  name: Name(Message),
  table: JobTable,
  settings: Settings,
) -> actor.StartResult(Subject(Message)) {
  actor.new_with_initialiser(1000, fn(named) {
    initialise(named, table, settings)
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn initialise(
  named: Subject(Message),
  table: JobTable,
  settings: Settings,
) -> Result(actor.Initialised(State, Message, Subject(Message)), String) {
  // The exit of a linked job becomes a message, and does not stop the worker
  process.trap_exits(True)
  let lost = mark_unfinished_jobs_lost(table, settings)
  settings.log(
    "the job worker started (lost jobs: " <> int.to_string(lost) <> ")",
  )
  let own = process.new_subject()
  process.send_after(own, settings.cleanup_interval, CleanUp)
  let selector =
    process.new_selector()
    |> process.select(named)
    |> process.select(own)
    |> process.select_trapped_exits(JobExited)
  State(
    settings:,
    table:,
    own:,
    queue: [],
    queued: 0,
    running: None,
    stop_replies: [],
    ended_jobs: set.new(),
  )
  |> actor.initialised
  |> actor.selecting(selector)
  |> actor.returning(named)
  |> Ok
}

/// A new worker after a crash of the old one: the jobs that waited or ran
/// in the old worker are gone, so their state becomes `Lost`.
fn mark_unfinished_jobs_lost(table: JobTable, settings: Settings) -> Int {
  let now = job_table.now_milliseconds()
  let unfinished =
    read_jobs(table, settings)
    |> list.filter(fn(job) { job.finished_at == None })
  list.each(unfinished, fn(job) {
    save(table, settings, Job(id: job.id, state: Lost, finished_at: Some(now)))
  })
  list.length(unfinished)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Submit(input:, reply:) -> submit_job(state, input, reply)
    Stop(reply:) -> stop_worker(state, reply)
    JobFinished(id:, result:) -> finish_job(state, id, result)
    JobExited(exit:) -> handle_exit(state, exit)
    JobTimedOut(id:) -> time_out_job(state, id)
    CleanUp -> clean_up(state)
  }
}

fn submit_job(
  state: State,
  input: String,
  reply: Subject(Result(Int, SubmitError)),
) -> actor.Next(State, Message) {
  let accepted = case
    state.stop_replies,
    state.queued >= state.settings.max_queued
  {
    [_, ..], _ -> Error(Stopping)
    [], True -> Error(QueueFull)
    [], False -> new_job_id(state)
  }
  case accepted {
    Ok(id) -> {
      save(
        state.table,
        state.settings,
        Job(id:, state: Queued, finished_at: None),
      )
      // The queue has at most `max_queued` jobs, so this append is short
      let state =
        State(
          ..state,
          queue: list.append(state.queue, [#(id, input)]),
          queued: state.queued + 1,
        )
        |> start_next_job
      process.send(reply, Ok(id))
      actor.continue(state)
    }
    Error(error) -> {
      process.send(reply, Error(error))
      actor.continue(state)
    }
  }
}

fn new_job_id(state: State) -> Result(Int, SubmitError) {
  job_table.next_id(state.table)
  |> result.map_error(fn(error) { NotSaved(string.inspect(error)) })
}

/// Starts the oldest job in the queue when no job runs
fn start_next_job(state: State) -> State {
  case state.running, state.stop_replies, state.queue {
    None, [], [#(id, input), ..rest] -> {
      let own = state.own
      let run_job = state.settings.run_job
      // Linked: the job ends when the worker ends. The worker traps
      // exits, so a crash of the job is a message.
      let pid =
        process.spawn(fn() {
          process.send(own, JobFinished(id, run_job(input)))
        })
      let timer =
        process.send_after(own, state.settings.job_timeout, JobTimedOut(id))
      save(
        state.table,
        state.settings,
        Job(id:, state: Running, finished_at: None),
      )
      state.settings.log("job " <> int.to_string(id) <> " started")
      State(
        ..state,
        queue: rest,
        queued: state.queued - 1,
        running: Some(RunningJob(id:, pid:, timer:)),
      )
    }
    _, _, _ -> state
  }
}

fn finish_job(
  state: State,
  id: Int,
  result: String,
) -> actor.Next(State, Message) {
  case state.running {
    Some(running) if running.id == id -> {
      process.cancel_timer(running.timer)
      // Its normal exit message comes next
      let ended_jobs = set.insert(state.ended_jobs, running.pid)
      end_job(State(..state, ended_jobs:), id, Done(result))
    }
    // A late result of a job that timed out
    _ -> actor.continue(state)
  }
}

fn time_out_job(state: State, id: Int) -> actor.Next(State, Message) {
  case state.running {
    Some(running) if running.id == id -> {
      process.kill(running.pid)
      // Its exit message with the reason `Killed` comes next
      let ended_jobs = set.insert(state.ended_jobs, running.pid)
      end_job(State(..state, ended_jobs:), id, TimedOut)
    }
    // The job finished just before its timer
    _ -> actor.continue(state)
  }
}

/// An exit message: from the running job, from a job that ended, or from
/// the supervisor that stops the worker
fn handle_exit(state: State, exit: ExitMessage) -> actor.Next(State, Message) {
  let ExitMessage(pid:, reason:) = exit
  case state.running, set.contains(state.ended_jobs, pid) {
    Some(running), _ if running.pid == pid -> {
      process.cancel_timer(running.timer)
      end_job(state, running.id, Failed(describe_exit(reason)))
    }
    _, True ->
      actor.continue(
        State(..state, ended_jobs: set.delete(state.ended_jobs, pid)),
      )
    // Not a job: the supervisor stops the worker. The running job ends too,
    // because it is linked.
    _, False -> exit_with(reason)
  }
}

fn exit_with(reason: ExitReason) -> actor.Next(State, Message) {
  case reason {
    Normal -> actor.stop()
    Killed -> actor.stop_abnormal("killed")
    Abnormal(reason:) -> exit_process(reason)
  }
}

/// Ends this process with `reason`, so the supervisor sees the reason that
/// it sent, for example `shutdown`
@external(erlang, "erlang", "exit")
fn exit_process(reason: Dynamic) -> actor.Next(State, Message)

fn end_job(
  state: State,
  id: Int,
  job_state: JobState,
) -> actor.Next(State, Message) {
  let now = job_table.now_milliseconds()
  save(
    state.table,
    state.settings,
    Job(id:, state: job_state, finished_at: Some(now)),
  )
  state.settings.log(
    "job " <> int.to_string(id) <> " " <> job_table.state_name(job_state),
  )
  let state = State(..state, running: None)
  case state.stop_replies {
    [] -> actor.continue(start_next_job(state))
    replies -> stop_now(state, replies)
  }
}

/// The reason of a crash, as the status route shows it. A panic gives its
/// message.
fn describe_exit(reason: ExitReason) -> String {
  case reason {
    Normal -> "the job ended with no result"
    Killed -> "the job was killed"
    Abnormal(reason:) -> describe_abnormal(reason)
  }
}

fn describe_abnormal(reason: Dynamic) -> String {
  let panic_message = {
    use message <- decode.field(
      0,
      decode.field(atom.create("message"), decode.string, decode.success),
    )
    decode.success(message)
  }
  case decode.run(reason, panic_message) {
    Ok(message) -> message
    Error(_errors) -> string.inspect(reason)
  }
}

fn stop_worker(
  state: State,
  reply: Subject(Nil),
) -> actor.Next(State, Message) {
  let replies = [reply, ..state.stop_replies]
  case state.running {
    Some(running) -> {
      state.settings.log(
        "stopping after job " <> int.to_string(running.id) <> " ends",
      )
      actor.continue(State(..state, stop_replies: replies))
    }
    None -> stop_now(state, replies)
  }
}

/// Cancels the jobs that wait, answers each caller of `stop`, and ends the
/// worker with a normal exit
fn stop_now(
  state: State,
  replies: List(Subject(Nil)),
) -> actor.Next(State, Message) {
  let now = job_table.now_milliseconds()
  list.each(state.queue, fn(queued) {
    let #(id, _input) = queued
    save(
      state.table,
      state.settings,
      Job(id:, state: Cancelled, finished_at: Some(now)),
    )
  })
  state.settings.log(
    "the job worker stopped (cancelled jobs: "
    <> int.to_string(state.queued)
    <> ")",
  )
  list.each(replies, process.send(_, Nil))
  actor.stop()
}

/// Removes the jobs that finished one `cleanup_interval` ago or before,
/// and sets the timer for the next cleanup
fn clean_up(state: State) -> actor.Next(State, Message) {
  let limit = job_table.now_milliseconds() - state.settings.cleanup_interval
  let old_jobs =
    read_jobs(state.table, state.settings)
    |> list.filter(finished_before(_, limit))
  list.each(old_jobs, fn(job) { remove(state.table, state.settings, job.id) })
  case old_jobs {
    [] -> Nil
    _ ->
      state.settings.log(
        "removed finished jobs: " <> int.to_string(list.length(old_jobs)),
      )
  }
  process.send_after(state.own, state.settings.cleanup_interval, CleanUp)
  actor.continue(state)
}

fn finished_before(job: Job, limit: Int) -> Bool {
  case job.finished_at {
    Some(time) -> time <= limit
    None -> False
  }
}

/// Writes `job` to the table. A failed write goes to the log.
fn save(table: JobTable, settings: Settings, job: Job) -> Nil {
  case job_table.save(table, job) {
    Ok(Nil) -> Nil
    Error(error) ->
      settings.log(
        "job "
        <> int.to_string(job.id)
        <> " was not saved: "
        <> string.inspect(error),
      )
  }
}

fn remove(table: JobTable, settings: Settings, id: Int) -> Nil {
  case job_table.delete(table, id) {
    Ok(Nil) -> Nil
    Error(error) ->
      settings.log(
        "job "
        <> int.to_string(id)
        <> " was not removed: "
        <> string.inspect(error),
      )
  }
}

/// Every job in the table. A failed read goes to the log, and gives no jobs.
fn read_jobs(table: JobTable, settings: Settings) -> List(Job) {
  case job_table.list(table) {
    Ok(jobs) -> jobs
    Error(error) -> {
      settings.log("the job table was not read: " <> string.inspect(error))
      []
    }
  }
}

/// Gives `input` to the worker. Waits at most `within` milliseconds for
/// the id of the new job.
pub fn submit(
  worker: Subject(Message),
  input: String,
  within timeout: Int,
) -> Result(Int, SubmitError) {
  case call_worker(worker, timeout, Submit(input, _)) {
    Ok(result) -> result
    Error(Nil) -> Error(NoAnswer)
  }
}

/// Stops the worker after the job that runs now. The jobs that wait are
/// cancelled. Waits at most `within` milliseconds for the running job.
pub fn stop(worker: Subject(Message), within timeout: Int) -> Result(Nil, Nil) {
  call_worker(worker, timeout, Stop)
}

/// Calls the worker, and waits at most `timeout` milliseconds. Gives
/// `Error(Nil)` at once when no worker is registered under the name.
fn call_worker(
  worker: Subject(Message),
  timeout: Int,
  make_message: fn(Subject(reply)) -> Message,
) -> Result(reply, Nil) {
  use _worker_pid <- result.try(process.subject_owner(worker))
  run_in_helper(fn() {
    process.call(worker, waiting: timeout, sending: make_message)
  })
}

/// Runs `work` in a new process that is not linked, and monitors it.
/// Returns `Error(Nil)` when that process ends without an answer: a call
/// that times out, or a worker that does not run. A late reply goes to
/// the helper, which has ended, so it never stays in the caller's mailbox.
fn run_in_helper(work: fn() -> a) -> Result(a, Nil) {
  let reply = process.new_subject()
  let helper = process.spawn_unlinked(fn() { process.send(reply, work()) })
  let monitor = process.monitor(helper)
  let result =
    process.new_selector()
    |> process.select_map(reply, Ok)
    |> process.select_specific_monitor(monitor, fn(_down) { Error(Nil) })
    |> process.selector_receive_forever
  process.demonitor_process(monitor)
  result
}
