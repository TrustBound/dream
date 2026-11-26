//// Tag operations - Business logic for tag management
////
//// This module contains pure domain logic for tag operations. It calls
//// the functions that dream_model generated in models/tag and models/task,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_errors
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
  use created <- result.try(
    tag.get_or_create(db, data.name, option.Some(option.unwrap(data.color, "")))
    |> result.map_error(tag_error),
  )
  use _ <- result.try(
    tag.add_to_task(db, task_id, created.id) |> result.map_error(tag_error),
  )

  Ok(created)
}

/// Add an existing tag to a task
pub fn add_tag_to_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag.add_to_task(db, task_id, tag_id) |> result.map_error(tag_error)
}

/// Remove a tag from a task. A tag that is not on the task gives NotFound.
pub fn remove_tag_from_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, Error) {
  tag.remove_from_task(db, task_id, tag_id)
  |> result.map_error(tag_on_task_error)
  |> result.replace(Nil)
}

/// Get all available tags
pub fn list_all(db: Connection) -> Result(List(Tag), Error) {
  tag.list(db) |> result.map_error(tag_error)
}

/// Get tags for a specific task
pub fn get_tags_for_task(
  db: Connection,
  task_id: Int,
) -> Result(List(Tag), Error) {
  tag.for_task(db, task_id) |> result.map_error(tag_error)
}

/// Get a task with its tags
///
/// Returns both the task and its associated tags in a single operation.
/// If getting tags fails, returns an empty list rather than failing the entire operation.
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

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn tag_error(model_error: dream_errors.Error(client.QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> error.NotFound("Tag not found")
    _ -> error.from_shared(model_error)
  }
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn tag_on_task_error(
  model_error: dream_errors.Error(client.QueryError),
) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> error.NotFound("Tag not found on task")
    _ -> error.from_shared(model_error)
  }
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn task_error(model_error: dream_errors.Error(client.QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> error.NotFound("Task not found")
    _ -> error.from_shared(model_error)
  }
}
