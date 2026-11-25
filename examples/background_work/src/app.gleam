//// Starts the parts of the app that run next to the server: the job table
//// and a supervisor with the job worker.

import gleam/erlang/process.{type Subject}
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string
import job_table
import job_worker
import services.{type Services, Services}

pub type App {
  App(services: Services, stop: Subject(Nil))
}

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
