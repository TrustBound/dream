//// Reorder tasks operation - business logic for drag-and-drop reordering

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/list
import gleam/result
import models/task.{type Task}
import utilities/response_helpers

/// Reorder a task by moving it to a new position
/// This operation could be extended to handle complex reordering logic,
/// such as updating positions of other tasks in the list
pub fn execute(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  task.update_position(db, task_id, new_position)
  |> result.map_error(task_error)
}

/// Batch reorder multiple tasks
/// Useful for drag-and-drop operations that affect multiple items
pub fn batch_reorder(
  db: Connection,
  updates: List(#(Int, Int)),
) -> Result(List(Task), Error) {
  batch_reorder_recursive(db, updates, [])
}

fn batch_reorder_recursive(
  db: Connection,
  updates: List(#(Int, Int)),
  results: List(Task),
) -> Result(List(Task), Error) {
  case updates {
    [] -> Ok(list.reverse(results))
    [#(task_id, position), ..rest] -> {
      use task_item <- result.try(
        task.update_position(db, task_id, position)
        |> result.map_error(task_error),
      )
      batch_reorder_recursive(db, rest, [task_item, ..results])
    }
  }
}

/// The Dream error of a model error, with the texts for the client.
fn task_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Task not found",
    conflicts: [],
  )
}
