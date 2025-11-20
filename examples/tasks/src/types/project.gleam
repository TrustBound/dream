//// Project domain type

import gleam/option.{type Option}

pub type Project {
  Project(
    id: Int,
    name: String,
    description: Option(String),
    color: Option(String),
    created_at: String,
  )
}

pub type ProjectData {
  ProjectData(name: String, description: Option(String), color: Option(String))
}
