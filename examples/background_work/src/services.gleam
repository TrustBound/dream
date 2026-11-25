//// The services of the app: the subject of the job worker and the job
//// table. Both stay the same when the supervisor starts a new worker.

import gleam/erlang/process.{type Subject}
import job_table.{type JobTable}
import job_worker

pub type Services {
  Services(worker: Subject(job_worker.Message), table: JobTable)
}
