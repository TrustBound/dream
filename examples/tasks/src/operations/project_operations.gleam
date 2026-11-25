//// Project operations - Business logic for project management
////
//// It calls the functions that dream_model generated in models/project,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option
import gleam/result
import models/project.{type Project}
import types/project.{type ProjectData} as _project_data
import utilities/response_helpers

/// Create a new project. A missing description or color is stored as an
/// empty text.
pub fn create_project(
  db: Connection,
  data: ProjectData,
) -> Result(Project, Error) {
  project.create(
    db,
    data.name,
    option.Some(option.unwrap(data.description, "")),
    option.Some(option.unwrap(data.color, "")),
  )
  |> result.map_error(project_error)
}

/// List all projects
pub fn list_projects(db: Connection) -> Result(List(Project), Error) {
  project.list(db)
  |> result.map_error(project_error)
}

/// Get a project by ID. A project that does not exist gives NotFound.
pub fn get_project(db: Connection, project_id: Int) -> Result(Project, Error) {
  project.get(db, project_id)
  |> result.map_error(project_error)
}

/// Delete a project
pub fn delete_project(db: Connection, project_id: Int) -> Result(Nil, Error) {
  project.delete(db, project_id)
  |> result.map_error(project_error)
}

/// The Dream error of a model error, with the texts for the client.
fn project_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Project not found",
    conflicts: [],
  )
}
