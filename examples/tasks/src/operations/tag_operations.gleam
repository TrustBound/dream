//// Tag operations - Business logic for tag management
////
//// This module contains pure domain logic for tag operations.
//// It returns Result types with dream.Error.

import dream/http/error.{type Error}
import gleam/option
import gleam/result
import models/tag/tag_model
import models/task/task_model
import pog.{type Connection}
import types/tag.{type Tag, TagData}
import types/task.{type Task}

/// Create a new tag and attach it to a task
///
/// Returns the newly created tag or an error.
pub fn create_and_attach(
  db: Connection,
  task_id: Int,
  tag_name: String,
) -> Result(Tag, Error) {
  let data = TagData(name: tag_name, color: option.None)

  use tag <- result.try(tag_model.get_or_create(db, data))
  use _ <- result.try(tag_model.add_to_task(db, task_id, tag.id))

  Ok(tag)
}

/// Add an existing tag to a task
pub fn add_tag_to_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag_model.add_to_task(db, task_id, tag_id)
}

/// Remove a tag from a task
pub fn remove_tag_from_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag_model.remove_from_task(db, task_id, tag_id)
}

/// Get all available tags
pub fn list_all(db: Connection) -> Result(List(Tag), Error) {
  tag_model.list(db)
}

/// Get tags for a specific task
pub fn get_tags_for_task(
  db: Connection,
  task_id: Int,
) -> Result(List(Tag), Error) {
  tag_model.get_tags_for_task(db, task_id)
}

/// Get a task with its tags
///
/// Returns both the task and its associated tags in a single operation.
/// If getting tags fails, returns an empty list rather than failing the entire operation.
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
