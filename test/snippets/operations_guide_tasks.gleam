//// Operations guide: an operation and the controller that calls it
////
//// Shown in excerpts in docs/guides/operations.md.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, json_response, ok, require_field_int,
  require_form, require_int, text_response,
}
import dream/http/error.{type Error, BadRequest, NotFound}
import gleam/json
import gleam/list
import gleam/result

pub type Task {
  Task(id: Int, title: String)
}

pub type Services {
  Services(tasks: List(Task))
}

pub fn reorder_task(
  services: Services,
  task_id: Int,
  new_position: Int,
) -> Result(List(Task), Error) {
  // In a real app, this might also:
  // 1. Check permissions
  // 2. Save the new order in the database
  // 3. Log the activity
  // 4. Broadcast an event via WebSocket
  use task <- result.try(find_task(services.tasks, task_id))
  use Nil <- result.try(check_position(services.tasks, new_position))
  let other_tasks =
    list.filter(services.tasks, fn(other) { other.id != task_id })
  // Shift the other tasks to make room
  let #(before, after) = list.split(other_tasks, new_position - 1)
  Ok(list.flatten([before, [task], after]))
}

pub fn reorder(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    use form <- result.try(require_form(request))
    use new_position <- result.try(require_field_int(form, "position"))
    reorder_task(services, id, new_position)
  }

  case result {
    Ok(tasks) -> json_response(ok, task_ids_to_json(tasks))
    Error(failure) -> respond_with_error(failure)
  }
}

fn find_task(tasks: List(Task), task_id: Int) -> Result(Task, Error) {
  list.find(tasks, fn(task) { task.id == task_id })
  |> result.replace_error(NotFound("Task not found"))
}

fn check_position(tasks: List(Task), position: Int) -> Result(Nil, Error) {
  case position >= 1 && position <= list.length(tasks) {
    True -> Ok(Nil)
    False -> Error(BadRequest("Position must be between 1 and the task count"))
  }
}

fn task_ids_to_json(tasks: List(Task)) -> String {
  json.array(tasks, fn(task) { json.int(task.id) })
  |> json.to_string
}

fn respond_with_error(failure: Error) -> Response {
  text_response(error.to_status_code(failure), error.message(failure))
}
