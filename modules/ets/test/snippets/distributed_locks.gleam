//// Distributed Locks
////
//// Example snippet showing a lock that only one owner can take.

import dream_ets/helpers
import dream_ets/operations
import dream_ets/table
import gleam/result
import gleam/string

pub fn acquire_lock(
  locks: table.Table(String, String),
  resource_id: String,
  owner_id: String,
) -> Result(String, String) {
  case operations.insert_new(locks, resource_id, owner_id) {
    Ok(True) -> Ok("Lock acquired")
    Ok(False) -> Error("Resource already locked")
    Error(error) -> Error("Lock system error: " <> string.inspect(error))
  }
}

pub fn acquire_lock_twice() -> Result(
  #(Result(String, String), Result(String, String)),
  table.EtsError,
) {
  use locks <- result.try(helpers.new_string_table("locks"))
  let first_attempt = acquire_lock(locks, "report:42", "worker:1")
  let second_attempt = acquire_lock(locks, "report:42", "worker:2")
  Ok(#(first_attempt, second_attempt))
}
