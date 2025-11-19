//// Tag model - data access layer

import dream_postgres/client.{type Connection}
import dream_postgres/query
import gleam/list
import models/tag/sql
import types/errors.{type DataError, DatabaseError}
import types/tag.{type Tag, type TagData, Tag}

/// List all tags
pub fn list(db: Connection) -> Result(List(Tag), DataError) {
  case sql.list_tags(db) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, row_to_tag))
    Error(_) -> Error(DatabaseError)
  }
}

/// Get or create a tag by name
pub fn get_or_create(
  db: Connection,
  data: TagData,
) -> Result(Tag, DataError) {
  let color = option.unwrap(data.color, "")
  case sql.get_or_create_tag(db, data.name, color) |> query.first_row() {
    Ok(row) -> Ok(get_or_create_row_to_tag(row))
    Error(_) -> Error(DatabaseError)
  }
}

/// Get all tags for a specific task
pub fn get_tags_for_task(
  db: Connection,
  task_id: Int,
) -> Result(List(Tag), DataError) {
  case sql.get_tags_for_task(db, task_id) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, get_tags_for_task_row_to_tag))
    Error(_) -> Error(DatabaseError)
  }
}

/// Add a tag to a task
pub fn add_to_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, DataError) {
  case sql.add_tag_to_task(db, task_id, tag_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(DatabaseError)
  }
}

/// Remove a tag from a task
pub fn remove_from_task(
  db: Connection,
  task_id: Int,
  tag_id: Int,
) -> Result(Nil, DataError) {
  case sql.remove_tag_from_task(db, task_id, tag_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(DatabaseError)
  }
}

import gleam/option

// Convert Squirrel row to domain type
fn row_to_tag(row: sql.ListTagsRow) -> Tag {
  Tag(id: row.id, name: row.name, color: row.color)
}

fn get_or_create_row_to_tag(row: sql.GetOrCreateTagRow) -> Tag {
  Tag(id: row.id, name: row.name, color: row.color)
}

fn get_tags_for_task_row_to_tag(row: sql.GetTagsForTaskRow) -> Tag {
  Tag(id: row.id, name: row.name, color: row.color)
}

