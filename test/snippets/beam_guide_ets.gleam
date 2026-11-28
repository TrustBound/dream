//// BEAM guide: who owns an ETS table

import gleam/otp/actor
import snippets/beam_guide_cache.{type Table}

/// Wrong: called from a request, the request process owns the table, and
/// the table goes away when the request ends
pub fn cache_for_request() -> Table {
  let table = beam_guide_cache.new_table()
  beam_guide_cache.insert(table, "sku-1", 100)
  table
}

/// Fix: start a process at startup that owns the table, and keep it
/// running. Give the table to the requests in your services.
pub fn start_table_owner() -> actor.StartResult(Table) {
  actor.new_with_initialiser(1000, fn(_subject) {
    let table = beam_guide_cache.new_table()
    beam_guide_cache.insert(table, "sku-1", 100)
    actor.initialised(Nil)
    |> actor.returning(table)
    |> Ok
  })
  |> actor.start
}
