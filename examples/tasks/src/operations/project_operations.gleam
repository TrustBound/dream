//// Project operations - Business logic for project management
////
//// It calls the functions that dream_model generated in models/project,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{type Connection, type QueryError}
import gleam/option.{Some, unwrap}
import gleam/result.{map_error}
import models/project.{type Project, create, delete, get, list}
import types/project.{type ProjectData} as _project_data

/// Create a new project. A missing description or color is stored as an
/// empty text.
pub fn create_project(
  db: Connection,
  data: ProjectData,
) -> Result(Project, Error) {
  create(
    db,
    data.name,
    Some(unwrap(data.description, "")),
    Some(unwrap(data.color, "")),
  )
  |> map_error(project_error)
}

/// List all projects
pub fn list_projects(db: Connection) -> Result(List(Project), Error) {
  list(db)
  |> map_error(project_error)
}

/// Get a project by ID. A project that does not exist gives NotFound.
pub fn get_project(db: Connection, project_id: Int) -> Result(Project, Error) {
  get(db, project_id)
  |> map_error(project_error)
}

/// Delete a project
pub fn delete_project(db: Connection, project_id: Int) -> Result(Nil, Error) {
  delete(db, project_id)
  |> map_error(project_error)
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn project_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("Project not found")
    _ -> from_shared(model_error)
  }
}
