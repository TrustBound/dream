//// Reorder tasks operation - business logic for drag-and-drop reordering

import dream_postgres/client.{type Connection}
import gleam/list
import models/task/task_model
import types/errors.{type DataError}
import types/task.{type Task}

/// Reorder a task by moving it to a new position
/// This operation could be extended to handle complex reordering logic,
/// such as updating positions of other tasks in the list
pub fn execute(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, DataError) {
  task_model.update_position(db, task_id, new_position)
}

/// Batch reorder multiple tasks
/// Useful for drag-and-drop operations that affect multiple items
pub fn batch_reorder(
  db: Connection,
  updates: List(#(Int, Int)),
) -> Result(List(Task), DataError) {
  batch_reorder_recursive(db, updates, [])
}

fn batch_reorder_recursive(
  db: Connection,
  updates: List(#(Int, Int)),
  results: List(Task),
) -> Result(List(Task), DataError) {
  case updates {
    [] -> Ok(list.reverse(results))
    [#(task_id, position), ..rest] ->
      case task_model.update_position(db, task_id, position) {
        Ok(task_item) ->
          batch_reorder_recursive(db, rest, [task_item, ..results])
        Error(err) -> Error(err)
      }
  }
}
