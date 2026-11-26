//// Projects controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http.{
  type Request, type Response, empty_response, html_response, no_content, ok,
  require_int,
}
import gleam/option.{None}
import gleam/result
import models/tag.{type Tag, for_task}
import models/task.{type Task}
import operations/project_operations.{
  create_project, delete_project, get_project, list_projects,
}
import operations/task_operations.{list_project_tasks}
import services.{type Services}
import types/project.{ProjectData} as _project_data
import utilities/response_helpers.{handle_error}
import views/project_view.{card, list_page, show_page}

/// List all projects
pub fn index(
  _request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  case list_projects(services.db) {
    Ok(projects) -> html_response(ok, list_page(projects))
    Error(err) -> handle_error(err)
  }
}

/// Show single project
pub fn show(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let result = {
    use project_id <- result.try(require_int(request, "project_id"))
    use found <- result.try(get_project(services.db, project_id))
    use tasks <- result.try(list_project_tasks(services.db, found.id))

    let tags_by_task = build_tags_by_task(services, tasks)
    Ok(#(found, tasks, tags_by_task))
  }

  case result {
    Ok(#(found, tasks, tags_by_task)) ->
      html_response(ok, show_page(found, tasks, tags_by_task))
    Error(err) -> handle_error(err)
  }
}

fn build_tags_by_task(
  services: Services,
  tasks: List(Task),
) -> List(#(Int, List(Tag))) {
  case tasks {
    [] -> []
    [first, ..rest] -> {
      let tags =
        for_task(services.db, first.id)
        |> result.unwrap([])
      [#(first.id, tags), ..build_tags_by_task(services, rest)]
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
  let data = ProjectData(name: "New Project", description: None, color: None)

  case create_project(services.db, data) {
    Ok(created) -> html_response(ok, card(created))
    Error(err) -> handle_error(err)
  }
}

/// Delete a project
pub fn delete(
  request: Request,
  _context: TasksContext,
  services: Services,
) -> Response {
  let result = {
    use project_id <- result.try(require_int(request, "project_id"))
    delete_project(services.db, project_id)
  }

  case result {
    Ok(_) -> empty_response(no_content)
    Error(err) -> handle_error(err)
  }
}
