//// Advanced Operations
////
//// Example snippet showing atomic take operation.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/option
import gleam/result

pub fn atomic_take() -> Result(String, table.EtsError) {
  use queue <- result.try(helpers.new_string_table("jobs"))

  // Add a job
  use _ <- result.try(operations.set(queue, "job:123", "send_email"))

  // Take and remove atomically
  use job <- result.try(operations.take(queue, "job:123"))

  case job {
    option.Some(task) -> Ok(task)
    option.None -> Error(table.OperationFailed("Job not found"))
  }
}
