//// This module contains the code to run the sql queries defined in
//// `./src/models/tag/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog

/// name: add_tag_to_task
/// Add a tag to a task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn add_tag_to_task(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- name: add_tag_to_task
-- Add a tag to a task
INSERT INTO task_tags (task_id, tag_id)
VALUES ($1, $2)
ON CONFLICT (task_id, tag_id) DO NOTHING;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_or_create_tag` query
/// defined in `./src/models/tag/sql/get_or_create_tag.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetOrCreateTagRow {
  GetOrCreateTagRow(id: Int, name: String, color: Option(String))
}

/// name: get_or_create_tag
/// Get or create a tag by name
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_or_create_tag(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(GetOrCreateTagRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.optional(decode.string))
    decode.success(GetOrCreateTagRow(id:, name:, color:))
  }

  "-- name: get_or_create_tag
-- Get or create a tag by name
INSERT INTO tags (name, color)
VALUES ($1, $2)
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
RETURNING
  id,
  name,
  color;

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_tags_for_task` query
/// defined in `./src/models/tag/sql/get_tags_for_task.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetTagsForTaskRow {
  GetTagsForTaskRow(id: Int, name: String, color: Option(String))
}

/// name: get_tags_for_task
/// Get all tags for a specific task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_tags_for_task(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetTagsForTaskRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.optional(decode.string))
    decode.success(GetTagsForTaskRow(id:, name:, color:))
  }

  "-- name: get_tags_for_task
-- Get all tags for a specific task
SELECT
  t.id,
  t.name,
  t.color
FROM tags t
INNER JOIN task_tags tt ON t.id = tt.tag_id
WHERE tt.task_id = $1
ORDER BY t.name ASC;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_tags` query
/// defined in `./src/models/tag/sql/list_tags.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListTagsRow {
  ListTagsRow(id: Int, name: String, color: Option(String))
}

/// name: list_tags
/// List all tags
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_tags(
  db: pog.Connection,
) -> Result(pog.Returned(ListTagsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use color <- decode.field(2, decode.optional(decode.string))
    decode.success(ListTagsRow(id:, name:, color:))
  }

  "-- name: list_tags
-- List all tags
SELECT
  id,
  name,
  color
FROM tags
ORDER BY name ASC;

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// name: remove_tag_from_task
/// Remove a tag from a task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn remove_tag_from_task(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- name: remove_tag_from_task
-- Remove a tag from a task
DELETE FROM task_tags
WHERE task_id = $1 AND tag_id = $2;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
