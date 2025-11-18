//// This module contains the code to run the sql queries defined in
//// `./src/models/project/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `create_project` query
/// defined in `./src/models/project/sql/create_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateProjectRow {
  CreateProjectRow(
    id: Int,
    name: String,
    description: Option(String),
    color: Option(String),
    created_at: Timestamp,
  )
}

/// name: create_project
/// Create a new project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_project(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(CreateProjectRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use color <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, pog.timestamp_decoder())
    decode.success(CreateProjectRow(
      id:,
      name:,
      description:,
      color:,
      created_at:,
    ))
  }

  "-- name: create_project
-- Create a new project
INSERT INTO projects (name, description, color)
VALUES ($1, $2, $3)
RETURNING
  id,
  name,
  description,
  color,
  created_at;

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// name: delete_project
/// Delete a project by ID
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_project(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- name: delete_project
-- Delete a project by ID
DELETE FROM projects
WHERE id = $1;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_project` query
/// defined in `./src/models/project/sql/get_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetProjectRow {
  GetProjectRow(
    id: Int,
    name: String,
    description: Option(String),
    color: Option(String),
    created_at: Timestamp,
  )
}

/// name: get_project
/// Get a single project by ID
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_project(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetProjectRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use color <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, pog.timestamp_decoder())
    decode.success(GetProjectRow(id:, name:, description:, color:, created_at:))
  }

  "-- name: get_project
-- Get a single project by ID
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
WHERE id = $1;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_projects` query
/// defined in `./src/models/project/sql/list_projects.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListProjectsRow {
  ListProjectsRow(
    id: Int,
    name: String,
    description: Option(String),
    color: Option(String),
    created_at: Timestamp,
  )
}

/// name: list_projects
/// List all projects
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_projects(
  db: pog.Connection,
) -> Result(pog.Returned(ListProjectsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use color <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, pog.timestamp_decoder())
    decode.success(ListProjectsRow(
      id:,
      name:,
      description:,
      color:,
      created_at:,
    ))
  }

  "-- name: list_projects
-- List all projects
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
ORDER BY created_at DESC;

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}
