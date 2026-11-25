//// Task operations - Business logic for task management
////
//// This module contains pure domain logic for task operations. It calls
//// the functions that dream_model generated in models/task and models/tag,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option.{type Option}
import gleam/result
import gleam/time/calendar
import models/tag.{type Tag}
import models/task.{type Task}
import types/task.{type TaskData, TaskData} as _task_data
import utilities/dates
import utilities/response_helpers

/// Create a new task
pub fn create_task(db: Connection, data: TaskData) -> Result(Task, Error) {
  task.create(
    db,
    data.title,
    stored_description(data.description),
    data.completed,
    data.priority,
    option.Some(stored_due_date(data.due_date)),
    data.position,
    option.unwrap(data.project_id, 0),
  )
  |> result.map_error(task_error)
}

/// Update an existing task
pub fn update_task(
  db: Connection,
  task_id: Int,
  data: TaskData,
) -> Result(Task, Error) {
  task.update(
    db,
    task_id,
    data.title,
    stored_description(data.description),
    data.completed,
    data.priority,
    option.Some(stored_due_date(data.due_date)),
    option.unwrap(data.project_id, 0),
  )
  |> result.map_error(task_error)
}

/// Get a task by ID
pub fn get_task(db: Connection, task_id: Int) -> Result(Task, Error) {
  task.get(db, task_id) |> result.map_error(task_error)
}

/// Get a task with its tags
pub fn get_task_with_tags(
  db: Connection,
  task_id: Int,
) -> Result(#(Task, List(Tag)), Error) {
  use found <- result.try(task.get(db, task_id) |> result.map_error(task_error))

  let tags =
    tag.for_task(db, found.id)
    |> result.map_error(tag_error)
    |> result.unwrap([])

  Ok(#(found, tags))
}

/// List all tasks
pub fn list_tasks(db: Connection) -> Result(List(Task), Error) {
  task.list(db) |> result.map_error(task_error)
}

/// List all tasks with their tags
///
/// Returns a list of tasks paired with a list of tags for each task.
pub fn list_tasks_with_tags(
  db: Connection,
) -> Result(List(#(Task, List(Tag))), Error) {
  use tasks <- result.try(task.list(db) |> result.map_error(task_error))

  // Get tags for each task
  let tasks_with_tags = build_tasks_with_tags(db, tasks)

  Ok(tasks_with_tags)
}

fn build_tasks_with_tags(
  db: Connection,
  tasks: List(Task),
) -> List(#(Task, List(Tag))) {
  case tasks {
    [] -> []
    [first, ..rest] -> {
      let tags =
        tag.for_task(db, first.id)
        |> result.map_error(tag_error)
        |> result.unwrap([])
      [#(first, tags), ..build_tasks_with_tags(db, rest)]
    }
  }
}

/// List the tasks of a project
pub fn list_project_tasks(
  db: Connection,
  project_id: Int,
) -> Result(List(Task), Error) {
  task.list_by_project(db, project_id)
  |> result.map_error(task_error)
}

/// Delete a task. A task that does not exist gives NotFound.
pub fn delete_task(db: Connection, task_id: Int) -> Result(Nil, Error) {
  task.delete(db, task_id)
  |> result.map_error(task_error)
  |> result.replace(Nil)
}

/// Toggle task completion status
pub fn toggle_completion(db: Connection, task_id: Int) -> Result(Task, Error) {
  task.toggle_completed(db, task_id) |> result.map_error(task_error)
}

/// Update task position (for reordering)
pub fn update_position(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  task.update_position(db, task_id, new_position)
  |> result.map_error(task_error)
}

/// Update a single field on a task (for auto-save)
pub fn update_field(
  db: Connection,
  task_id: Int,
  field: String,
  value: String,
) -> Result(Nil, Error) {
  use found <- result.try(task.get(db, task_id) |> result.map_error(task_error))
  let data =
    TaskData(
      title: found.title,
      description: found.description,
      completed: found.completed,
      priority: found.priority,
      due_date: option.map(found.due_date, dates.date_to_string),
      position: found.position,
      project_id: found.project_id,
    )
  let data = case field {
    "title" -> TaskData(..data, title: value)
    "description" -> TaskData(..data, description: non_empty(value))
    "due_date" -> TaskData(..data, due_date: non_empty(value))
    _ -> data
  }
  use _updated <- result.try(update_task(db, task_id, data))
  Ok(Nil)
}

// A task with no description stores an empty description.
fn stored_description(description: Option(String)) -> Option(String) {
  option.Some(option.unwrap(description, ""))
}

// A task with no due date, or with a date that does not parse, stores
// 2025-01-01.
fn stored_due_date(due_date: Option(String)) -> calendar.Date {
  due_date
  |> option.then(dates.parse_date)
  |> option.unwrap(calendar.Date(year: 2025, month: calendar.January, day: 1))
}

fn non_empty(value: String) -> Option(String) {
  case value {
    "" -> option.None
    _ -> option.Some(value)
  }
}

/// The Dream error of a model error, with the texts for the client.
fn tag_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Tag not found",
    conflicts: [],
  )
}

/// The Dream error of a model error, with the texts for the client.
fn task_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Task not found",
    conflicts: [],
  )
}
