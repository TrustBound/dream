//// Reorder tasks operation - business logic for drag-and-drop reordering

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{type Connection, type QueryError}
import gleam/list.{reverse}
import gleam/result.{map_error, try}
import models/task.{type Task, update_position}

/// Reorder a task by moving it to a new position
/// This operation could be extended to handle complex reordering logic,
/// such as updating positions of other tasks in the list
pub fn execute(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  update_position(db, task_id, new_position)
  |> map_error(task_error)
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
    [] -> Ok(reverse(results))
    [#(task_id, position), ..rest] -> {
      use task_item <- try(
        update_position(db, task_id, position)
        |> map_error(task_error),
      )
      batch_reorder_recursive(db, rest, [task_item, ..results])
    }
  }
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn task_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("Task not found")
    _ -> from_shared(model_error)
  }
}
