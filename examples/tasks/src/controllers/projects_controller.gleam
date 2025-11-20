//// Projects controller - HTTP handlers with HTMX support

import context.{type TasksContext}
import dream/http
import gleam/option
import gleam/result
import models/project/project_model
import models/tag/tag_model
import models/task/task_model
import services.{type Services}
import types/project.{ProjectData}
import types/tag.{type Tag}
import types/task.{type Task}
import utilities/response_helpers
import views/project_view

/// List all projects
pub fn index(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  case project_model.list(services.db) {
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
    use project <- result.try(project_model.get(services.db, project_id))
    use tasks <- result.try(task_model.list_by_project(services.db, project.id))

    let tags_by_task = build_tags_by_task(services, tasks)
    Ok(#(project, tasks, tags_by_task))
  }

  case result {
    Ok(#(project, tasks, tags_by_task)) ->
      http.html_response(
        http.ok,
        project_view.show_page(project, tasks, tags_by_task),
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
    [task, ..rest] -> {
      let tags =
        tag_model.get_tags_for_task(services.db, task.id)
        |> result.unwrap([])
      [#(task.id, tags), ..build_tags_by_task(services, rest)]
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

  case project_model.create(services.db, data) {
    Ok(project) -> http.html_response(http.ok, project_view.card(project))
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
    project_model.delete(services.db, project_id)
  }

  case result {
    Ok(_) -> http.empty_response(http.no_content)
    Error(err) -> response_helpers.handle_error(err)
  }
}
