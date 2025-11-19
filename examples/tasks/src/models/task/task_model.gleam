//// Task model - data access layer

import dream_postgres/client.{type Connection}
import dream_postgres/query
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import models/task/sql
import types/errors.{type DataError, DatabaseError, NotFound}
import types/task.{type Task, type TaskData, Task}

/// Get a single task by ID
pub fn get(db: Connection, task_id: Int) -> Result(Task, DataError) {
  case sql.get_task(db, task_id) |> query.first_row() {
    Ok(row) -> Ok(row_to_task(row))
    Error(query.NotFound) -> Error(NotFound)
    Error(query.DatabaseError) -> Error(DatabaseError)
  }
}

/// List all tasks
pub fn list(db: Connection) -> Result(List(Task), DataError) {
  io.println("Model: Executing list_tasks query...")
  case sql.list_tasks(db) |> query.all_rows() {
    Ok(rows) -> {
      io.println(
        "Model: Got " <> int.to_string(list.length(rows)) <> " tasks from DB",
      )
      Ok(list.map(rows, list_row_to_task))
    }
    Error(_) -> {
      io.println("Model: Query failed or error extracting rows")
      Error(DatabaseError)
    }
  }
}

/// List tasks by project
pub fn list_by_project(
  db: Connection,
  project_id: Int,
) -> Result(List(Task), DataError) {
  case sql.list_by_project(db, project_id) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, list_by_project_row_to_task))
    Error(_) -> Error(DatabaseError)
  }
}

/// Create a new task
pub fn create(db: Connection, data: TaskData) -> Result(Task, DataError) {
  let description = option.unwrap(data.description, "")
  let default_date = calendar.Date(year: 2025, month: calendar.January, day: 1)
  let due_date = case data.due_date {
    option.Some(date_str) -> {
      case parse_date_string(date_str) {
        option.Some(parsed_date) -> parsed_date
        option.None -> default_date
      }
    }
    option.None -> default_date
  }
  let project_id = option.unwrap(data.project_id, 0)

  case
    sql.create_task(
      db,
      data.title,
      description,
      data.completed,
      data.priority,
      due_date,
      data.position,
      project_id,
    )
    |> query.first_row()
  {
    Ok(row) -> Ok(create_row_to_task(row))
    Error(_) -> Error(DatabaseError)
  }
}

/// Update a task
pub fn update(
  db: Connection,
  task_id: Int,
  data: TaskData,
) -> Result(Task, DataError) {
  let description = option.unwrap(data.description, "")
  let default_date = calendar.Date(year: 2025, month: calendar.January, day: 1)
  let due_date = case data.due_date {
    option.Some(date_str) -> {
      case parse_date_string(date_str) {
        option.Some(parsed_date) -> parsed_date
        option.None -> default_date
      }
    }
    option.None -> default_date
  }
  let project_id = option.unwrap(data.project_id, 0)

  case
    sql.update_task(
      db,
      task_id,
      data.title,
      description,
      data.completed,
      data.priority,
      due_date,
      project_id,
    )
    |> query.first_row()
  {
    Ok(row) -> Ok(update_row_to_task(row))
    Error(query.NotFound) -> Error(NotFound)
    Error(_) -> Error(DatabaseError)
  }
}

/// Delete a task
pub fn delete(db: Connection, task_id: Int) -> Result(Nil, DataError) {
  case sql.delete_task(db, task_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(DatabaseError)
  }
}

/// Toggle the completed status of a task
pub fn toggle_completed(db: Connection, task_id: Int) -> Result(Task, DataError) {
  case sql.toggle_completed(db, task_id) |> query.first_row() {
    Ok(row) -> Ok(toggle_row_to_task(row))
    Error(query.NotFound) -> Error(NotFound)
    Error(_) -> Error(DatabaseError)
  }
}

/// Update the position of a task
pub fn update_position(
  db: Connection,
  task_id: Int,
  position: Int,
) -> Result(Task, DataError) {
  case sql.update_position(db, task_id, position) |> query.first_row() {
    Ok(row) -> Ok(update_position_row_to_task(row))
    Error(query.NotFound) -> Error(NotFound)
    Error(_) -> Error(DatabaseError)
  }
}

// Convert Squirrel row to domain type
fn row_to_task(row: sql.GetTaskRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn list_row_to_task(row: sql.ListTasksRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn list_by_project_row_to_task(row: sql.ListByProjectRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn create_row_to_task(row: sql.CreateTaskRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn update_row_to_task(row: sql.UpdateTaskRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn toggle_row_to_task(row: sql.ToggleCompletedRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn update_position_row_to_task(row: sql.UpdatePositionRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    description: row.description,
    completed: row.completed,
    priority: row.priority,
    due_date: option.map(row.due_date, calendar_date_to_string),
    position: row.position,
    project_id: row.project_id,
    created_at: timestamp_to_string(row.created_at),
    updated_at: timestamp_to_string(row.updated_at),
  )
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  let unix_float = timestamp.to_unix_seconds(ts)
  let unix_int = float.truncate(unix_float)
  int.to_string(unix_int)
}

fn calendar_date_to_string(date: calendar.Date) -> String {
  let calendar.Date(year: y, month: m, day: d) = date
  let month_int = month_to_int(m)
  int.to_string(y)
  <> "-"
  <> pad_zero(int.to_string(month_int))
  <> "-"
  <> pad_zero(int.to_string(d))
}

fn month_to_int(month: calendar.Month) -> Int {
  case month {
    calendar.January -> 1
    calendar.February -> 2
    calendar.March -> 3
    calendar.April -> 4
    calendar.May -> 5
    calendar.June -> 6
    calendar.July -> 7
    calendar.August -> 8
    calendar.September -> 9
    calendar.October -> 10
    calendar.November -> 11
    calendar.December -> 12
  }
}

fn pad_zero(s: String) -> String {
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

/// Parse date string (YYYY-MM-DD) into calendar.Date
/// Returns None if parsing fails
fn parse_date_string(date_str: String) -> option.Option(calendar.Date) {
  case string.split(date_str, "-") {
    [year_str, month_str, day_str] -> {
      case int.parse(year_str), int.parse(month_str), int.parse(day_str) {
        Ok(year), Ok(month_int), Ok(day) -> {
          case int_to_month(month_int) {
            option.Some(month) ->
              option.Some(calendar.Date(year: year, month: month, day: day))
            option.None -> option.None
          }
        }
        _, _, _ -> option.None
      }
    }
    _ -> option.None
  }
}

fn int_to_month(month_int: Int) -> option.Option(calendar.Month) {
  case month_int {
    1 -> option.Some(calendar.January)
    2 -> option.Some(calendar.February)
    3 -> option.Some(calendar.March)
    4 -> option.Some(calendar.April)
    5 -> option.Some(calendar.May)
    6 -> option.Some(calendar.June)
    7 -> option.Some(calendar.July)
    8 -> option.Some(calendar.August)
    9 -> option.Some(calendar.September)
    10 -> option.Some(calendar.October)
    11 -> option.Some(calendar.November)
    12 -> option.Some(calendar.December)
    _ -> option.None
  }
}
