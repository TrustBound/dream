//// This module contains the code to run the sql queries defined in
//// `./src/models/task/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `create_task` query
/// defined in `./src/models/task/sql/create_task.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateTaskRow {
  CreateTaskRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: create_task
/// Create a new task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_task(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Bool,
  arg_4: Int,
  arg_5: Date,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(CreateTaskRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(CreateTaskRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: create_task
-- Create a new task
INSERT INTO tasks (
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id
)
VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, 0))
RETURNING
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at;

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.bool(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.calendar_date(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// name: delete_task
/// Delete a task by ID
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_task(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- name: delete_task
-- Delete a task by ID
DELETE FROM tasks
WHERE id = $1;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_task` query
/// defined in `./src/models/task/sql/get_task.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetTaskRow {
  GetTaskRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: get_task
/// Get a single task by ID
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_task(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetTaskRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(GetTaskRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: get_task
-- Get a single task by ID
SELECT
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at
FROM tasks
WHERE id = $1;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_by_project` query
/// defined in `./src/models/task/sql/list_by_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListByProjectRow {
  ListByProjectRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: list_by_project
/// List all tasks for a specific project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_by_project(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ListByProjectRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(ListByProjectRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: list_by_project
-- List all tasks for a specific project
SELECT
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at
FROM tasks
WHERE project_id = $1
ORDER BY position ASC, created_at DESC;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_tasks` query
/// defined in `./src/models/task/sql/list_tasks.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListTasksRow {
  ListTasksRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: list_tasks
/// List all tasks ordered by position
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_tasks(
  db: pog.Connection,
) -> Result(pog.Returned(ListTasksRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(ListTasksRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: list_tasks
-- List all tasks ordered by position
SELECT
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at
FROM tasks
ORDER BY position ASC, created_at DESC;

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `toggle_completed` query
/// defined in `./src/models/task/sql/toggle_completed.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ToggleCompletedRow {
  ToggleCompletedRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: toggle_completed
/// Toggle the completed status of a task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn toggle_completed(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ToggleCompletedRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(ToggleCompletedRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: toggle_completed
-- Toggle the completed status of a task
UPDATE tasks
SET
  completed = NOT completed,
  updated_at = NOW()
WHERE id = $1
RETURNING
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `update_position` query
/// defined in `./src/models/task/sql/update_position.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpdatePositionRow {
  UpdatePositionRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: update_position
/// Update the position of a task for drag-and-drop reordering
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_position(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(UpdatePositionRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(UpdatePositionRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: update_position
-- Update the position of a task for drag-and-drop reordering
UPDATE tasks
SET position = $2
WHERE id = $1
RETURNING
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `update_task` query
/// defined in `./src/models/task/sql/update_task.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpdateTaskRow {
  UpdateTaskRow(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(Date),
    position: Int,
    project_id: Option(Int),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// name: update_task
/// Update a task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_task(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Bool,
  arg_5: Int,
  arg_6: Date,
  arg_7: Int,
) -> Result(pog.Returned(UpdateTaskRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use description <- decode.field(2, decode.optional(decode.string))
    use completed <- decode.field(3, decode.bool)
    use priority <- decode.field(4, decode.int)
    use due_date <- decode.field(
      5,
      decode.optional(pog.calendar_date_decoder()),
    )
    use position <- decode.field(6, decode.int)
    use project_id <- decode.field(7, decode.optional(decode.int))
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(UpdateTaskRow(
      id:,
      title:,
      description:,
      completed:,
      priority:,
      due_date:,
      position:,
      project_id:,
      created_at:,
      updated_at:,
    ))
  }

  "-- name: update_task
-- Update a task
UPDATE tasks
SET
  title = $2,
  description = $3,
  completed = $4,
  priority = $5,
  due_date = $6,
  project_id = NULLIF($7, 0),
  updated_at = NOW()
WHERE id = $1
RETURNING
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at;

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.bool(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.calendar_date(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
