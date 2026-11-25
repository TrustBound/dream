//// Project operations - Business logic for project management
////
//// It calls the functions that dream_model generated in models/project,
//// which return Result types with dream.Error.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/option
import models/project.{type Project}
import types/project.{type ProjectData} as _project_data

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
}
