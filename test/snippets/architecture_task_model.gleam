//// Architecture reference: a model
////
//// Finds a task and returns a domain type or a Dream error. It reads from a
//// list so that the example runs anywhere; a real model runs a query.

import dream/http/error.{type Error, NotFound}
import gleam/list
import gleam/result
import snippets/architecture_task.{type Task}

pub fn get_task(tasks: List(Task), task_id: Int) -> Result(Task, Error) {
  list.find(tasks, fn(task) { task.id == task_id })
  |> result.replace_error(NotFound("Task not found"))
}
