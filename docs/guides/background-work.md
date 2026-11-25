# Run background work

Some work is too slow for a request: a PDF, a large export, an email to a list of customers. When a controller does this work, the client waits for all of it, and the connection stays busy. The fix is to accept the job, answer at once, and do the work in another process. The [BEAM guide](https://hexdocs.pm/dream/3.0.0/guides/beam.html#slow-work-in-a-request) shows this in a few lines. This guide builds the full version: a job worker that a supervisor starts, a queue with a limit, a timeout for each job, a cleanup on a timer, and a stop that lets the running job finish. We use [`gleam_otp`](https://hexdocs.pm/gleam_otp/1.2.0/) and [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/), and no job library, so each part is code that you can read.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Keep the job states in a table](#step-1-keep-the-job-states-in-a-table)
- [Step 2: Describe the worker](#step-2-describe-the-worker)
- [Step 3: Start the worker before the server](#step-3-start-the-worker-before-the-server)
- [Step 4: Answer 202 at once](#step-4-answer-202-at-once)
- [Step 5: Put a limit on the queue](#step-5-put-a-limit-on-the-queue)
- [Step 6: Give each job a timeout](#step-6-give-each-job-a-timeout)
- [Step 7: Mark a crashed job failed](#step-7-mark-a-crashed-job-failed)
- [Step 8: See what a crash of the worker loses](#step-8-see-what-a-crash-of-the-worker-loses)
- [Step 9: Clean up on a timer](#step-9-clean-up-on-a-timer)
- [Step 10: Stop after the running job](#step-10-stop-after-the-running-job)
- [Step 11: Test without sleep](#step-11-test-without-sleep)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, we:

- Accept a job with `POST /jobs`, and answer `202 Accepted` with the job id and a status route.
- Run the jobs in an actor that a supervisor starts before the server.
- Answer `503` when too many jobs wait.
- Stop a job that runs too long.
- Mark a job that crashes as failed, and go on with the queue.
- See what a crash of the worker loses, and what stays.
- Remove old jobs with a timer message, not a sleep loop.
- Stop the worker after the job that runs now.

All the code is in [`examples/background_work`](https://github.com/TrustBound/dream/tree/3.0.0/examples/background_work). Its tests compare each output on this page with the real app.

## Before you start

You need a Dream app. If you do not have one, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html). Read the [BEAM guide](https://hexdocs.pm/dream/3.0.0/guides/beam.html) first. This guide links to its sections.

The worker is an actor from `gleam_otp`. The job table uses `dream_ets`. The responses use `gleam_json`:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/gleam.toml#L8-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_ets = ">= 3.0.0 and < 4.0.0"
gleam_erlang = ">= 1.0.0 and < 2.0.0"
gleam_json = ">= 2.2.0 and < 4.0.0"
gleam_otp = ">= 1.2.0 and < 2.0.0"
```

## Step 1: Keep the job states in a table

A client sends a job, and later asks for its state. Where does the app keep that state? There are two good places:

| Place | A status read | After a crash of the worker |
|:---|:---|:---|
| The state of the worker | A call to the worker. It waits while the worker is busy. | The states are gone. The client gets `404` for its job. |
| An ETS table that a longer-lived process owns | A read of the table, with no call | The states stay. The new worker can mark the old jobs as lost. |

We use the table. Status reads never wait in the worker's mailbox ([One process that every request calls](https://hexdocs.pm/dream/3.0.0/guides/beam.html#one-process-that-every-request-calls)), and an id never comes back after a crash. A table dies with its owner ([An ETS table dies with its owner](https://hexdocs.pm/dream/3.0.0/guides/beam.html#an-ets-table-dies-with-its-owner)). Thus the owner is not the worker. It is a process that lives as long as the app.

`dream_ets` makes public tables, because the owner does not write to them. Only the worker writes. Each request only reads. One table holds the jobs, and a counter table holds the last id:

### Make the tables and the next id <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_table.gleam#L38-L54"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

A job has one of the states `Queued`, `Running`, `Done`, `Failed`, `TimedOut`, `Lost` and `Cancelled`. Each table has a name, so the app gives a name to `app.start`, and each test gives its own name.

## Step 2: Describe the worker

The worker gets everything that can change from its `Settings`. The work of a job is a function, so a test can give a job that it controls. The limits and the intervals are numbers, so a test can make them short:

### The settings and the messages of the worker <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L26-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

Requests send `Submit` and `Stop`. The worker's own jobs and timers send `JobFinished`, `JobTimedOut` and `CleanUp`, and the runtime sends `JobExited` when a job process ends.

## Step 3: Start the worker before the server

A supervisor starts the worker, and starts it again after a crash ([A supervisor starts a failed process again](https://hexdocs.pm/dream/3.0.0/guides/beam.html#a-supervisor-starts-a-failed-process-again)). The worker registers under a name. A new worker takes the same name, so the subject in the services stays correct after a restart:

### Start the worker under a name <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L84-L108"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

`Transient` means: start the worker again after a crash, but not after a normal stop. Without it, the supervisor starts a new worker after each clean stop of [step 10](#step-10-stop-after-the-running-job).

One owner process makes the table and starts the supervisor. Then it waits, and keeps both alive:

### The owner of the table and the supervisor <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/app.gleam#L16-L65"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts the owner process of the app and waits for its services. The
/// owner makes the job table, named after `name`, and starts the
/// supervisor, so the table and the supervisor live as long as the owner.
pub fn start(
  name: String,
  settings: job_worker.Settings,
) -> Result(App, String) {
  let reply = process.new_subject()
  process.spawn(fn() { run_owner(name, settings, reply) })
  process.receive(reply, within: 5000)
  |> result.replace_error("The app did not start in 5 seconds")
  |> result.flatten
}

/// Ends the owner process. Its supervisor and the job table end with it.
pub fn stop(app: App) -> Nil {
  process.send(app.stop, Nil)
}

fn run_owner(
  name: String,
  settings: job_worker.Settings,
  reply: Subject(Result(App, String)),
) -> Nil {
  case start_services(name, settings) {
    Ok(services) -> {
      let stop = process.new_subject()
      process.send(reply, Ok(App(services:, stop:)))
      process.receive_forever(stop)
    }
    Error(message) -> process.send(reply, Error(message))
  }
}

fn start_services(
  name: String,
  settings: job_worker.Settings,
) -> Result(Services, String) {
  use table <- result.try(
    job_table.new(name) |> result.map_error(string.inspect),
  )
  let worker_name = process.new_name("job_worker")
  use _supervisor <- result.map(
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(job_worker.supervised(worker_name, table, settings))
    |> supervisor.start
    |> result.map_error(string.inspect),
  )
  Services(worker: process.named_subject(worker_name), table:)
}
```

`main` starts the app first. When the server takes its first request, the worker is ready:

### Start the worker, then the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/main.gleam#L16-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() -> Nil {
  let settings =
    Settings(
      run_job: report.summarise,
      max_queued: 100,
      job_timeout: 30_000,
      cleanup_interval: 60_000,
      log: io.println,
    )
  // The job worker starts before the server, so the first request finds it
  case app.start("jobs", settings) {
    Ok(started) -> start_server(started.services)
    Error(message) -> io.println_error("The app did not start: " <> message)
  }
}

fn start_server(services: Services) -> Nil {
  let assert Ok(Nil) =
    server.new()
    |> server.services(services)
    |> server.router(create_router())
    |> server.bind("localhost")
    |> server.listen(3000)
  Nil
}
```

The services hold the subject of the worker and the job table, and nothing else.

## Step 4: Answer 202 at once

The controller gives the job to the worker and answers. It does not wait for the job:

### The controller of POST /jobs <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/jobs_controller.gleam#L29-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
}

fn submit(services: Services, input: String) -> Response {
  case job_worker.submit(services.worker, input, within: 1000) {
    Ok(id) -> json_response(status.accepted, accepted_json(id))
    Error(QueueFull) ->
      busy("The job queue is full. Try again in a few seconds.")
    Error(Stopping) -> busy("The job worker is stopping.")
    Error(NoAnswer) -> busy("The job worker did not answer.")
    Error(NotSaved(reason:)) -> busy("The job was not saved: " <> reason)
  }
}

/// 503 with `retry-after`: the server is too busy now, for each client
fn busy(message: String) -> Response {
  let response = json_response(status.service_unavailable, error_json(message))
  Response(
    ..response,
    headers: add_header(response.headers, "retry-after", "5"),
  )
}
```

`job_worker.submit` waits at most one second for the id ([A call with no timeout](https://hexdocs.pm/dream/3.0.0/guides/beam.html#a-call-with-no-timeout)). `process.call` panics at the end of its time, so the call runs in a monitored helper, as in [Links and monitors](https://hexdocs.pm/dream/3.0.0/guides/beam.html#links-and-monitors). A worker that does not answer becomes `NoAnswer`, and the controller answers `503`:

### Call the worker with a limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L456-L486"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The test sends a job, reads its state while it runs, lets it finish, and reads the state again:

### A job from 202 to done <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/job_accepted.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
log: the job worker started (lost jobs: 0)
POST /jobs sales by region and team
  202 {"id":1,"status_url":"/jobs/1"}
log: job 1 started
GET /jobs/1
  200 {"id":1,"state":"running"}
log: job 1 done
GET /jobs/1
  200 {"id":1,"state":"done","result":"words: 5, lines: 1"}
```

`GET /jobs/:id` reads the table, and gives `404` for an id that it does not know.

## Step 5: Put a limit on the queue

`process.send` never waits. When jobs come faster than the worker finishes them, a worker that takes each job as a message gets a mailbox with no limit ([A mailbox that grows without limit](https://hexdocs.pm/dream/3.0.0/guides/beam.html#a-mailbox-that-grows-without-limit)). Our worker takes jobs with a call, and answers each call at once, because the job itself runs in another process. Thus the mailbox holds at most one message for each request that waits. The jobs wait in a list with a limit, `max_queued`:

### Accept a job, or say that the queue is full <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L171-L212"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

A full queue gives `503 Service Unavailable` with `retry-after`, not `429 Too Many Requests`. A `429` tells one client that it sent too many requests. Here, no client did anything wrong: the server is behind for all of its clients. A `503` says that, and clients try again later. Use `429` for the limit of each client, as in [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html).

With `max_queued: 2`, job 1 runs, jobs 2 and 3 wait, and job 4 gets `503`:

### The fourth job when two jobs wait <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/queue_full.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
POST /jobs second
  202 {"id":2,"status_url":"/jobs/2"}
POST /jobs third
  202 {"id":3,"status_url":"/jobs/3"}
POST /jobs fourth
  503 retry-after: 5 {"error":"The job queue is full. Try again in a few seconds."}
GET /jobs/3
  200 {"id":3,"state":"queued"}
```

## Step 6: Give each job a timeout

A process cannot stop itself in the middle of a function. Thus each job runs in its own process, and the worker stays free to receive messages. The worker links the job process to itself, and starts a timer with `process.send_after`:

### Start the next job and its timer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L214-L243"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The job and the timer send to `own`, a subject that only this worker process receives from. A message for a dead worker cannot reach the next one.

When the timer comes first, the worker kills the job process, and starts the next job. A result that comes after the timeout, or a timer that comes after the result, names a job that does not run now, and the worker ignores it:

### Finish a job, or stop it at its timeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L245-L273"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

Each job that ended this way still sends one exit message, because of the link. The worker keeps the process in `ended_jobs` until that message comes. [Step 7](#step-7-mark-a-crashed-job-failed) shows where the worker receives it.

With a timeout of 300 ms, job 1 never finishes, and job 2 runs after it. Then the test waits for the end of both job processes, and counts the messages in the mailbox of the worker:

### A job that runs too long <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/job_timeout.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
POST /jobs second
  202 {"id":2,"status_url":"/jobs/2"}
log: job 1 started
log: job 1 timed_out
log: job 2 started
log: job 2 done
GET /jobs/1
  200 {"id":1,"state":"timed_out"}
GET /jobs/2
  200 {"id":2,"state":"done","result":"words: 1, lines: 1"}
the process of job 1 ended: Killed
the process of job 2 ended: Normal
POST /jobs third
  202 {"id":3,"status_url":"/jobs/3"}
messages in the worker mailbox: 0
```

Job 1 ended with `Killed`, and job 2 with `Normal`. The worker received both exit messages, so no message stays in its mailbox ([A mailbox that grows without limit](https://hexdocs.pm/dream/3.0.0/guides/beam.html#a-mailbox-that-grows-without-limit)).

## Step 7: Mark a crashed job failed

A crash in a job is a bug in that job, not in the worker. The worker must see it, and the job must not outlive the worker. A plain link stops the worker with the job. A monitor alone lets the job run on after the worker crashed. [Links and monitors](https://hexdocs.pm/dream/3.0.0/guides/beam.html#links-and-monitors) shows both. A process that owns other processes does both things with one tool: it links them and traps exits. This is how an OTP supervisor watches its children. The initialiser turns it on:

### Trap exits in the worker <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L115-L127"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

With `trap_exits`, the end of a linked process is a message, not a crash. Each exit message comes from one of three places:

### Handle an exit message <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L275-L305"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

- From the running job: the job crashed. The worker marks it `failed` with the reason, and starts the next job.
- From a job in `ended_jobs`: the job finished or timed out before. The worker removes it from the set.
- From any other process: the supervisor stops the worker. The worker ends with the same reason, for example `shutdown`, and the link ends the running job.

`describe_exit` gives the message of a panic, so the client reads why its job failed. In this test, job 1 crashes while job 2 waits:

### A crash of job 1 with job 2 in the queue <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/job_crash.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
POST /jobs second
  202 {"id":2,"status_url":"/jobs/2"}
log: job 1 started
(the test makes job 1 crash)
log: job 1 failed
log: job 2 started
GET /jobs/1
  200 {"id":1,"state":"failed","reason":"the job crashed"}
GET /jobs/2
  200 {"id":2,"state":"running"}
```

The queue goes on, and only the job with the bug fails. The VM also logs the crash of the job process, with its stack trace.

## Step 8: See what a crash of the worker loses

The worker itself can crash too: a bug in its own code, or a kill. Then the supervisor starts a new worker under the same name. The queue was in the state of the old worker, so it is gone. The job table is not: its owner is another process. The new worker finds the jobs that did not finish, and marks them as lost:

### Mark the jobs of the old worker as lost <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L144-L155"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

In this test, job 1 runs and jobs 2 and 3 wait. The test watches the process of job 1, and kills the worker:

### A killed worker with two jobs in the queue <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/worker_crash.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
POST /jobs second
  202 {"id":2,"status_url":"/jobs/2"}
POST /jobs third
  202 {"id":3,"status_url":"/jobs/3"}
(the test kills the worker)
log: the job worker started (lost jobs: 3)
GET /jobs/1
  200 {"id":1,"state":"lost"}
GET /jobs/2
  200 {"id":2,"state":"lost"}
GET /jobs/3
  200 {"id":3,"state":"lost"}
POST /jobs fourth
  202 {"id":4,"status_url":"/jobs/4"}
log: job 4 started
the process of job 1 ended: Killed
GET /jobs/1
  200 {"id":1,"state":"lost"}
```

These things stay after the crash:

- The state of each job, so the client sees `lost`, not a `404`.
- The id counter, so job 4 gets id 4, and no id comes back.
- The name, so the services reach the new worker.

These things are lost:

- The job that ran. The link ended its process with the worker (`Killed`), so it does not run on with no worker to take its result.
- The input of each job that waited. It was in the state of the old worker.
- Everything, when the app itself stops. The table is in memory.

A supervisor gives back a working process, not its data. To keep jobs through a crash or a deploy, the next step is a durable queue: store each job, its input and its state in the database before you answer `202`, and let the worker take jobs from there. This guide does not build that. [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) shows the database part.

The supervisor also has a limit. By default, more than two restarts in five seconds stop the supervisor, and with it the owner and the app.

## Step 9: Clean up on a timer

Finished jobs stay in the table until something removes them. A loop that sleeps for a minute and then cleans up makes a process that receives nothing while it sleeps. A timer message is better: the worker gets `CleanUp` like any other message, between two jobs. The initialiser sends the first one:

### The first cleanup timer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L121-L122"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let own = process.new_subject()
  process.send_after(own, settings.cleanup_interval, CleanUp)
```

Each cleanup removes the jobs that finished one interval ago or before, and starts the next timer:

### Remove old jobs, then start the next timer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L392-L416"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The time comes from `cleanup_interval`, so a test sets it to 200 ms and does not wait a minute:

### A finished job after the cleanup <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/cleanup.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
log: job 1 done
GET /jobs/1
  200 {"id":1,"state":"done","result":"words: 1, lines: 1"}
log: removed finished jobs: 1
GET /jobs/1
  404 {"error":"No job 1"}
```

## Step 10: Stop after the running job

A stop must not cut a job in half. `job_worker.stop` sends `Stop`. When a job runs, the worker keeps the caller and stops after the job. When no job runs, it stops at once:

### Stop after the running job <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/src/job_worker.gleam#L352-L390"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

While it stops, the worker answers each new `Submit` with `Stopping`, and the controller answers `503`. The jobs that wait become `cancelled`, so their clients know that the jobs will not run:

### A stop while job 1 runs <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/clean_stop.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /jobs first
  202 {"id":1,"status_url":"/jobs/1"}
POST /jobs second
  202 {"id":2,"status_url":"/jobs/2"}
(the test calls stop with a limit of 5000 ms)
log: stopping after job 1 ends
POST /jobs third
  503 retry-after: 5 {"error":"The job worker is stopping."}
log: job 1 done
log: the job worker stopped (cancelled jobs: 1)
stop returned Ok(Nil)
GET /jobs/1
  200 {"id":1,"state":"done","result":"words: 1, lines: 1"}
GET /jobs/2
  200 {"id":2,"state":"cancelled"}
POST /jobs fourth
  503 retry-after: 5 {"error":"The job worker did not answer."}
```

Call `stop` where your app stops on purpose, for example in a test or in an admin route. On `SIGTERM`, Dream drains the running requests ([Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html)). Then the VM stops, and it ends processes that are not part of an OTP application, this worker too. A job that runs at that moment is lost. The durable queue of [step 8](#step-8-see-what-a-crash-of-the-worker-loses) is also the fix for this case.

## Step 11: Test without sleep

A test that sleeps guesses how long the work takes ([Sleep in a test](https://hexdocs.pm/dream/3.0.0/guides/beam.html#sleep-in-a-test)). These tests wait for messages, each with a limit of five seconds. The test settings give a job that tells the test when it starts, and then waits for the test to let it finish or crash. Each log line comes to the test as a message:

### Settings that the test controls <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/job_setup.gleam#L20-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

A wait for a log line is a wait for the event itself. The line comes after the worker wrote the table, so the next request sees the new state:

### Wait for a log line <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/job_setup.gleam#L65-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

To see that a job process ended, the test monitors it and waits for its down message. `mailbox_size` reads the mailbox length of the worker with `process_info`:

### Wait for the end of a job, and count messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/job_setup.gleam#L82-L105"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

The timeout and cleanup tests set short intervals, and wait for the log line of the timer. Run the tests:

### The test target <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/Makefile#L8-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile
test:
	@gleam test
```

## Common pitfalls

**A linked job without trapped exits.** *Symptom:* one bad job crashes the worker, and the queue is lost. *Fix:* call `process.trap_exits(True)` in the initialiser, and handle the exit messages, as in [step 7](#step-7-mark-a-crashed-job-failed).

**A job that is only monitored.** *Symptom:* after a crash of the worker, the old job still runs, and its result goes nowhere. *Fix:* link the job to the worker, as in [step 7](#step-7-mark-a-crashed-job-failed).

**Trapped exits with no handler.** *Symptom:* the supervisor waits five seconds and then kills the worker on each stop. *Fix:* end the worker when an exit message comes from a process that is not one of its jobs.

**The supervisor starts the worker again after a stop.** *Symptom:* `stop` returns, but a new worker takes jobs. *Fix:* give the child `supervision.Transient`.

**A worker that crashes again and again stops the app.** *Symptom:* after three restarts in five seconds, the app stops. *Fix:* find the bug in the worker. A crash in a job does not count, because the worker traps it.

## Where to go next

- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html): the short form of each trap that this guide avoids.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): the database for a durable queue.
- [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html): more about `dream_ets`, and a limit for each client.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): what happens on `SIGTERM`.
- [`gleam_otp` actors](https://hexdocs.pm/gleam_otp/1.2.0/gleam/otp/actor.html) and [static supervisors](https://hexdocs.pm/gleam_otp/1.2.0/gleam/otp/static_supervisor.html): the full API.
