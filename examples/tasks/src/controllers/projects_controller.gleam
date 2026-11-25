//// Projects controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http
import gleam/option
import gleam/result
import models/tag.{type Tag}
import models/task.{type Task}
import operations/project_operations
import operations/task_operations
import services.{type Services}
import types/project.{ProjectData} as _project_data
import utilities/response_helpers
import views/project_view

/// List all projects
pub fn index(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  case project_operations.list_projects(services.db) {
    Ok(projects) ->
      http.html_response(http.ok, project_view.list_page(projects))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Show single project
pub fn show(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use project_id <- result.try(http.require_int(request, "project_id"))
    use found <- result.try(project_operations.get_project(
      services.db,
      project_id,
    ))
    use tasks <- result.try(task_operations.list_project_tasks(
      services.db,
      found.id,
    ))

    let tags_by_task = build_tags_by_task(services, tasks)
    Ok(#(found, tasks, tags_by_task))
  }

  case result {
    Ok(#(found, tasks, tags_by_task)) ->
      http.html_response(
        http.ok,
        project_view.show_page(found, tasks, tags_by_task),
      )
    Error(err) -> response_helpers.handle_error(err)
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
        tag.for_task(services.db, first.id)
        |> result.unwrap([])
      [#(first.id, tags), ..build_tags_by_task(services, rest)]
    }
  }
}

/// Create a new project
pub fn create(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  // Placeholder - would need JSON/form validation
  let data =
    ProjectData(
      name: "New Project",
      description: option.None,
      color: option.None,
    )

  case project_operations.create_project(services.db, data) {
    Ok(created) -> http.html_response(http.ok, project_view.card(created))
    Error(err) -> response_helpers.handle_error(err)
  }
}

/// Delete a project
pub fn delete(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use project_id <- result.try(http.require_int(request, "project_id"))
    project_operations.delete_project(services.db, project_id)
  }

  case result {
    Ok(_) -> http.empty_response(http.no_content)
    Error(err) -> response_helpers.handle_error(err)
  }
}
