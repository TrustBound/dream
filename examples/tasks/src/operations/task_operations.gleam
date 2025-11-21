//// Task operations - Business logic for task management
////
//// This module contains pure domain logic for task operations.
//// It returns Result types with dream.Error.

import dream/http/error.{type Error}
import gleam/result
import models/tag/tag_model
import models/task/task_model
import pog.{type Connection}
import types/tag.{type Tag}
import types/task.{type Task, type TaskData}

/// Create a new task
pub fn create_task(db: Connection, data: TaskData) -> Result(Task, Error) {
  task_model.create(db, data)
}

/// Update an existing task
pub fn update_task(
  db: Connection,
  task_id: Int,
  data: TaskData,
) -> Result(Task, Error) {
  task_model.update(db, task_id, data)
}

/// Get a task by ID
pub fn get_task(db: Connection, task_id: Int) -> Result(Task, Error) {
  task_model.get(db, task_id)
}

/// Get a task with its tags
pub fn get_task_with_tags(
  db: Connection,
  task_id: Int,
) -> Result(#(Task, List(Tag)), Error) {
  use task <- result.try(task_model.get(db, task_id))

  let tags =
    tag_model.get_tags_for_task(db, task.id)
    |> result.unwrap([])

  Ok(#(task, tags))
}

/// List all tasks
pub fn list_tasks(db: Connection) -> Result(List(Task), Error) {
  task_model.list(db)
}

/// List all tasks with their tags
///
/// Returns a list of tasks paired with a list of tags for each task.
pub fn list_tasks_with_tags(
  db: Connection,
) -> Result(List(#(Task, List(Tag))), Error) {
  use tasks <- result.try(task_model.list(db))

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
    [task, ..rest] -> {
      let tags =
        tag_model.get_tags_for_task(db, task.id)
        |> result.unwrap([])
      [#(task, tags), ..build_tasks_with_tags(db, rest)]
    }
  }
}

/// Delete a task
pub fn delete_task(db: Connection, task_id: Int) -> Result(Nil, Error) {
  task_model.delete(db, task_id)
}

/// Toggle task completion status
pub fn toggle_completion(db: Connection, task_id: Int) -> Result(Task, Error) {
  task_model.toggle_completed(db, task_id)
}

/// Update task position (for reordering)
pub fn update_position(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  task_model.update_position(db, task_id, new_position)
}

/// Update a single field on a task
pub fn update_field(
  db: Connection,
  task_id: Int,
  field: String,
  value: String,
) -> Result(Nil, Error) {
  use _task <- result.try(task_model.update_field(db, task_id, field, value))
  Ok(Nil)
}
