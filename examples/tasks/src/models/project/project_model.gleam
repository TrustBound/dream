//// Project model - data access layer

import dream/http/error.{type Error, InternalServerError, NotFound}
import dream_postgres/client.{type Connection}
import dream_postgres/query
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp
import models/project/sql
import types/project.{type Project, type ProjectData, Project}

/// Get a single project by ID
pub fn get(db: Connection, project_id: Int) -> Result(Project, Error) {
  case sql.get_project(db, project_id) |> query.first_row() {
    Ok(row) -> Ok(row_to_project(row))
    Error(query.NotFound) -> Error(NotFound("Project not found"))
    Error(query.DatabaseError) -> Error(InternalServerError("Database error"))
  }
}

/// List all projects
pub fn list(db: Connection) -> Result(List(Project), Error) {
  case sql.list_projects(db) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, list_row_to_project))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Create a new project
pub fn create(db: Connection, data: ProjectData) -> Result(Project, Error) {
  let description = option.unwrap(data.description, "")
  let color = option.unwrap(data.color, "")

  case
    sql.create_project(db, data.name, description, color)
    |> query.first_row()
  {
    Ok(row) -> Ok(create_row_to_project(row))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

/// Delete a project
pub fn delete(db: Connection, project_id: Int) -> Result(Nil, Error) {
  case sql.delete_project(db, project_id) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

// Convert Squirrel row to domain type
fn row_to_project(row: sql.GetProjectRow) -> Project {
  Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    created_at: timestamp_to_string(row.created_at),
  )
}

fn list_row_to_project(row: sql.ListProjectsRow) -> Project {
  Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    created_at: timestamp_to_string(row.created_at),
  )
}

fn create_row_to_project(row: sql.CreateProjectRow) -> Project {
  Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    created_at: timestamp_to_string(row.created_at),
  )
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  let unix_float = timestamp.to_unix_seconds(ts)
  let unix_int = float.truncate(unix_float)
  int.to_string(unix_int)
}
