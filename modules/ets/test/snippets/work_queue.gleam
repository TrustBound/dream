//// Work Queue
////
//// Example snippet showing how a worker claims a job from a queue.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result
import gleam/string

pub fn claim_next_job(queue: table.Table(String, String)) -> String {
  case operations.take(queue, "next_job") {
    Ok(option.Some(job)) -> "Claimed " <> job
    Ok(option.None) -> "No jobs waiting"
    Error(error) -> "Queue error: " <> string.inspect(error)
  }
}

pub fn claim_next_job_twice() -> Result(#(String, String), table.EtsError) {
  use queue <- result.try(helpers.new_string_table("work_queue"))
  use _ <- result.try(operations.set(queue, "next_job", "send_email"))
  let first_claim = claim_next_job(queue)
  let second_claim = claim_next_job(queue)
  Ok(#(first_claim, second_claim))
}
