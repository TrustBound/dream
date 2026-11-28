//// BEAM guide: a message is a copy

import gleam/erlang/process.{type Subject}

/// Wrong: sends all the rows. The worker gets its own copy of each one.
pub fn export_rows(worker: Subject(List(Int)), rows: List(Int)) -> Nil {
  process.send(worker, rows)
}

/// Fix: send the ID of the export, and let the worker read the rows
pub fn export_by_id(worker: Subject(Int), export_id: Int) -> Nil {
  process.send(worker, export_id)
}

/// A binary of more than 64 bytes is not copied: the receiver gets a
/// reference to the same bytes
pub fn export_csv(worker: Subject(BitArray), csv: BitArray) -> Nil {
  process.send(worker, csv)
}
