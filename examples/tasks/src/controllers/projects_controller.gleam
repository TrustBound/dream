//// Projects controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, empty_response, html_response}
import dream/http/status
import gleam/option
import models/project/project_model
import models/tag/tag_model
import models/task/task_model
import services.{type Services}
import types/project.{type Project, ProjectData}
import types/tag.{type Tag}
import types/task.{type Task}
import views/errors
import views/project_view

/// List all projects
pub fn index(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  case project_model.list(services.db) {
    Ok(projects) -> html_response(status.ok, project_view.list_page(projects))
    Error(_) -> errors.internal_error()
  }
}

/// Show single project
pub fn show(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "project_id")
  let assert Ok(project_id) = param.as_int

  case project_model.get(services.db, project_id) {
    Ok(project) -> show_with_tasks(services, project, param.format)
    Error(_) -> errors.not_found("Project not found")
  }
}

fn show_with_tasks(
  services: Services,
  project: Project,
  format: option.Option(String),
) -> Response {
  case task_model.list_by_project(services.db, project.id) {
    Ok(tasks) -> {
      // Build tags for tasks
      let tags_by_task = build_tags_by_task(services, tasks)

      case format {
        option.Some("htmx") ->
          html_response(status.ok, project_view.card(project))
        _ ->
          html_response(
            status.ok,
            project_view.show_page(project, tasks, tags_by_task),
          )
      }
    }
    Error(_) -> errors.internal_error()
  }
}

fn build_tags_by_task(
  services: Services,
  tasks: List(Task),
) -> List(#(Int, List(Tag))) {
  case tasks {
    [] -> []
    [task, ..rest] -> {
      let tags = case tag_model.get_tags_for_task(services.db, task.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      [#(task.id, tags), ..build_tags_by_task(services, rest)]
    }
  }
}

/// Create a new project
pub fn create(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  // Placeholder - would need JSON/form validation
  let data =
    ProjectData(
      name: "New Project",
      description: option.None,
      color: option.None,
    )

  case project_model.create(services.db, data) {
    Ok(project) -> html_response(status.ok, project_view.card(project))
    Error(_) -> errors.internal_error()
  }
}

/// Delete a project
pub fn delete(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "project_id")
  let assert Ok(project_id) = param.as_int

  case project_model.delete(services.db, project_id) {
    Ok(_) -> empty_response(status.no_content)
    Error(_) -> errors.internal_error()
  }
}
