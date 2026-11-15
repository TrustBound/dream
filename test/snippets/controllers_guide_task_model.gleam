//// The task model that the controllers-and-models guide's controllers call.

import dream/http/error.{type Error, NotFound}
import gleam/list
import snippets/controllers_guide_services.{type Connection}
import snippets/controllers_guide_task.{type Task}

pub fn get(db: Connection, id: Int) -> Result(Task, Error) {
  db.tasks
  |> list.find(fn(task) { task.id == id })
  |> result_or_not_found()
}

fn result_or_not_found(found: Result(Task, Nil)) -> Result(Task, Error) {
  case found {
    Ok(task) -> Ok(task)
    Error(_) -> Error(NotFound("Task not found"))
  }
}
