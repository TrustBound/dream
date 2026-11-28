//// An app that runs jobs in the background.
////
//// Run it with `gleam run -m main`, then:
////
////   curl -i -X POST --data 'one two three' http://localhost:3000/jobs
////   curl -i http://localhost:3000/jobs/1

import app
import dream/servers/mist/server
import gleam/io
import job_worker.{Settings}
import report
import router.{create_router}
import services.{type Services}

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
