//// Project input type
////
//// The data of a new project. dream_model generates the Project record of
//// a row in models/project.

import gleam/option.{type Option}

pub type ProjectData {
  ProjectData(name: String, description: Option(String), color: Option(String))
}
