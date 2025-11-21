//// Project view - presentation layer

import gleam/json
import gleam/option
import templates/components/layout_components
import templates/components/project_components
import templates/components/task_components
import templates/pages/project as project_page
import types/project.{type Project}
import types/tag.{type Tag}
import types/task.{type Task}

/// Render project card for HTMX swap
pub fn card(project: Project) -> String {
  project_components.project_card(project)
}

/// Render project detail page
pub fn show_page(
  project: Project,
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let description = option.unwrap(project.description, "")
  let task_list = task_components.task_list(tasks, tags_by_task)

  let content =
    project_page.render(
      project_name: project.name,
      project_description: description,
      task_list: task_list,
    )

  layout_components.build_page(project.name, content)
}

/// Render list of projects
pub fn list_page(projects: List(Project)) -> String {
  let form = project_components.project_form_html()
  let list = project_components.project_list(projects)
  let content =
    "<section>"
    <> "<header><h1>Projects</h1></header>"
    <> form
    <> list
    <> "</section>"

  layout_components.build_page("Projects", content)
}

/// Convert project to JSON
pub fn to_json(project: Project) -> String {
  json.object([
    #("id", json.int(project.id)),
    #("name", json.string(project.name)),
    #("description", json_option_string(project.description)),
    #("color", json_option_string(project.color)),
    #("created_at", json.string(project.created_at)),
  ])
  |> json.to_string
}

/// Convert list of projects to JSON
pub fn list_to_json(projects: List(Project)) -> String {
  json.array(projects, project_to_json_object)
  |> json.to_string
}

fn project_to_json_object(project: Project) -> json.Json {
  json.object([
    #("id", json.int(project.id)),
    #("name", json.string(project.name)),
    #("description", json_option_string(project.description)),
    #("color", json_option_string(project.color)),
    #("created_at", json.string(project.created_at)),
  ])
}

fn json_option_string(opt: option.Option(String)) -> json.Json {
  case opt {
    option.Some(val) -> json.string(val)
    option.None -> json.null()
  }
}
