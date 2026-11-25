//// Tag operations - Business logic for tag management
////
//// This module contains pure domain logic for tag operations. It calls
//// the functions that dream_model generated in models/tag and models/task,
//// which return Result types with dream.Error.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option
import gleam/result
import models/tag.{type Tag}
import models/task.{type Task}
import types/tag.{TagData} as _tag_data

/// Create a new tag and attach it to a task
///
/// Returns the newly created tag or an error.
pub fn create_and_attach(
  db: Connection,
  task_id: Int,
  tag_name: String,
) -> Result(Tag, Error) {
  let data = TagData(name: tag_name, color: option.None)

  // A tag with no color stores an empty color.
  use created <- result.try(tag.get_or_create(
    db,
    data.name,
    option.Some(option.unwrap(data.color, "")),
  ))
  use _ <- result.try(tag.add_to_task(db, task_id, created.id))

  Ok(created)
}

/// Add an existing tag to a task
pub fn add_tag_to_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag.add_to_task(db, task_id, tag_id)
}

/// Remove a tag from a task. A tag that is not on the task gives NotFound.
pub fn remove_tag_from_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag.remove_from_task(db, task_id, tag_id)
  |> result.replace(Nil)
}

/// Get all available tags
pub fn list_all(db: Connection) -> Result(List(Tag), Error) {
  tag.list(db)
}

/// Get tags for a specific task
pub fn get_tags_for_task(
  db: Connection,
  task_id: Int,
) -> Result(List(Tag), Error) {
  tag.for_task(db, task_id)
}

/// Get a task with its tags
///
/// Returns both the task and its associated tags in a single operation.
/// If getting tags fails, returns an empty list rather than failing the entire operation.
pub fn get_task_with_tags(
  db: Connection,
  task_id: Int,
) -> Result(#(Task, List(Tag)), Error) {
  use found <- result.try(task.get(db, task_id))

  let tags =
    tag.for_task(db, found.id)
    |> result.unwrap([])

  Ok(#(found, tags))
}
