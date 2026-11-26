//// Task operations - Business logic for task management
////
//// This module contains pure domain logic for task operations. It calls
//// the functions that dream_model generated in models/task and models/tag,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{type Connection, type QueryError}
import gleam/option.{type Option, None, Some, map, then}
import gleam/result.{map_error, replace, try}
import gleam/time/calendar.{type Date, Date, January}
import models/tag.{type Tag, for_task}
import models/task.{
  type Task, create, delete, get, list, list_by_project, toggle_completed,
  update,
}
import types/task.{type TaskData, TaskData} as _task_data
import utilities/dates.{date_to_string, parse_date}

/// Create a new task
pub fn create_task(db: Connection, data: TaskData) -> Result(Task, Error) {
  create(
    db,
    data.title,
    stored_description(data.description),
    data.completed,
    data.priority,
    Some(stored_due_date(data.due_date)),
    data.position,
    option.unwrap(data.project_id, 0),
  )
  |> map_error(task_error)
}

/// Update an existing task
pub fn update_task(
  db: Connection,
  task_id: Int,
  data: TaskData,
) -> Result(Task, Error) {
  update(
    db,
    task_id,
    data.title,
    stored_description(data.description),
    data.completed,
    data.priority,
    Some(stored_due_date(data.due_date)),
    option.unwrap(data.project_id, 0),
  )
  |> map_error(task_error)
}

/// Get a task by ID
pub fn get_task(db: Connection, task_id: Int) -> Result(Task, Error) {
  get(db, task_id) |> map_error(task_error)
}

/// Get a task with its tags
pub fn get_task_with_tags(
  db: Connection,
  task_id: Int,
) -> Result(#(Task, List(Tag)), Error) {
  use found <- try(get(db, task_id) |> map_error(task_error))

  let tags =
    for_task(db, found.id)
    |> map_error(tag_error)
    |> result.unwrap([])

  Ok(#(found, tags))
}

/// List all tasks
pub fn list_tasks(db: Connection) -> Result(List(Task), Error) {
  list(db) |> map_error(task_error)
}

/// List all tasks with their tags
///
/// Returns a list of tasks paired with a list of tags for each task.
pub fn list_tasks_with_tags(
  db: Connection,
) -> Result(List(#(Task, List(Tag))), Error) {
  use tasks <- try(list(db) |> map_error(task_error))

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
        for_task(db, first.id)
        |> map_error(tag_error)
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
  list_by_project(db, project_id)
  |> map_error(task_error)
}

/// Delete a task. A task that does not exist gives NotFound.
pub fn delete_task(db: Connection, task_id: Int) -> Result(Nil, Error) {
  delete(db, task_id)
  |> map_error(task_error)
  |> replace(Nil)
}

/// Toggle task completion status
pub fn toggle_completion(db: Connection, task_id: Int) -> Result(Task, Error) {
  toggle_completed(db, task_id) |> map_error(task_error)
}

/// Update task position (for reordering)
pub fn update_position(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  task.update_position(db, task_id, new_position)
  |> map_error(task_error)
}

/// Update a single field on a task (for auto-save)
pub fn update_field(
  db: Connection,
  task_id: Int,
  field: String,
  value: String,
) -> Result(Nil, Error) {
  use found <- try(get(db, task_id) |> map_error(task_error))
  let data =
    TaskData(
      title: found.title,
      description: found.description,
      completed: found.completed,
      priority: found.priority,
      due_date: map(found.due_date, date_to_string),
      position: found.position,
      project_id: found.project_id,
    )
  let data = case field {
    "title" -> TaskData(..data, title: value)
    "description" -> TaskData(..data, description: non_empty(value))
    "due_date" -> TaskData(..data, due_date: non_empty(value))
    _ -> data
  }
  use _updated <- try(update_task(db, task_id, data))
  Ok(Nil)
}

// A task with no description stores an empty description.
fn stored_description(description: Option(String)) -> Option(String) {
  Some(option.unwrap(description, ""))
}

// A task with no due date, or with a date that does not parse, stores
// 2025-01-01.
fn stored_due_date(due_date: Option(String)) -> Date {
  due_date
  |> then(parse_date)
  |> option.unwrap(Date(year: 2025, month: January, day: 1))
}

fn non_empty(value: String) -> Option(String) {
  case value {
    "" -> None
    _ -> Some(value)
  }
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn tag_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("Tag not found")
    _ -> from_shared(model_error)
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
