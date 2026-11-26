//// Project view - presentation layer

import gleam/json.{type Json, array, int, null, object, string, to_string}
import gleam/option.{type Option, None, Some, unwrap}
import models/project.{type Project}
import models/tag.{type Tag}
import models/task.{type Task}
import templates/components/layout_components.{build_page}
import templates/components/project_components.{
  project_card, project_form_html, project_list,
}
import templates/components/task_components
import templates/pages/project.{render} as _
import utilities/dates.{timestamp_to_string}

/// Render project card for HTMX swap
pub fn card(project: Project) -> String {
  project_card(project)
}

/// Render project detail page
pub fn show_page(
  project: Project,
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let description = unwrap(project.description, "")
  let task_list = task_components.task_list(tasks, tags_by_task)

  let content =
    render(
      project_name: project.name,
      project_description: description,
      task_list: task_list,
    )

  build_page(project.name, content)
}

/// Render list of projects
pub fn list_page(projects: List(Project)) -> String {
  let form = project_form_html()
  let list = project_list(projects)
  let content =
    "<section>"
    <> "<header><h1>Projects</h1></header>"
    <> form
    <> list
    <> "</section>"

  build_page("Projects", content)
}

/// Convert project to JSON
pub fn to_json(project: Project) -> String {
  object([
    #("id", int(project.id)),
    #("name", string(project.name)),
    #("description", json_option_string(project.description)),
    #("color", json_option_string(project.color)),
    #("created_at", string(timestamp_to_string(project.created_at))),
  ])
  |> to_string
}

/// Convert list of projects to JSON
pub fn list_to_json(projects: List(Project)) -> String {
  array(projects, project_to_json_object)
  |> to_string
}

fn project_to_json_object(project: Project) -> Json {
  object([
    #("id", int(project.id)),
    #("name", string(project.name)),
    #("description", json_option_string(project.description)),
    #("color", json_option_string(project.color)),
    #("created_at", string(timestamp_to_string(project.created_at))),
  ])
}

fn json_option_string(opt: Option(String)) -> Json {
  case opt {
    Some(val) -> string(val)
    None -> null()
  }
}
