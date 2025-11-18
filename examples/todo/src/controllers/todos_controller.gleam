//// Todos controller - HTTP handlers with HTMX support

import dream/context.{type AppContext}
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, empty_response, html_response}
import dream/http/status
import gleam/option
import models/tag/model as tag_model
import models/task/model as todo_model
import services.{type Services}
import types/task.{TaskData}
import views/errors
import views/todo_view

/// Show single todo
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "todo_id")
  let assert Ok(todo_id) = param.as_int

  case todo_model.get(services.db, todo_id) {
    Ok(task) -> show_with_tags(services, task, param.format)
    Error(_) -> errors.not_found("Todo not found")
  }
}

fn show_with_tags(
  services: Services,
  task: types/task.Task,
  format: option.Option(String),
) -> Response {
  case tag_model.get_tags_for_todo(services.db, task.id) {
    Ok(tags) -> respond_with_format(task, tags, format)
    Error(_) -> respond_with_format(task, [], format)
  }
}

fn respond_with_format(
  task: types/task.Task,
  tags: List(types/tag.Tag),
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("htmx") -> html_response(status.ok, todo_view.card(task, tags))
    _ -> html_response(status.ok, todo_view.to_json(task))
  }
}

/// List all todos
pub fn index(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case todo_model.list(services.db) {
    Ok(tasks) -> index_with_tags(services, tasks)
    Error(_) -> errors.internal_error()
  }
}

fn index_with_tags(services: Services, tasks: List(types/task.Task)) -> Response {
  // Get tags for all todos
  let tags_by_todo = build_tags_by_todo(services, tasks)
  html_response(status.ok, todo_view.index_page(tasks, tags_by_todo))
}

fn build_tags_by_todo(
  services: Services,
  tasks: List(types/task.Task),
) -> List(#(Int, List(types/tag.Tag))) {
  case tasks {
    [] -> []
    [task, ..rest] -> {
      let tags = case tag_model.get_tags_for_todo(services.db, task.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      [#(task.id, tags), ..build_tags_by_todo(services, rest)]
    }
  }
}

/// Create a new todo
pub fn create(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  // For now, return placeholder - would need JSON validation
  let data =
    TaskData(
      title: "New Todo",
      description: option.None,
      completed: False,
      priority: 3,
      due_date: option.None,
      position: 0,
      project_id: option.None,
    )

  case todo_model.create(services.db, data) {
    Ok(task) -> html_response(status.ok, todo_view.card(task, []))
    Error(_) -> errors.internal_error()
  }
}

/// Update a todo
pub fn update(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "todo_id")
  let assert Ok(todo_id) = param.as_int

  // Placeholder - would need JSON validation
  let data =
    TaskData(
      title: "Updated Todo",
      description: option.None,
      completed: False,
      priority: 3,
      due_date: option.None,
      position: 0,
      project_id: option.None,
    )

  case todo_model.update(services.db, todo_id, data) {
    Ok(task) -> html_response(status.ok, todo_view.card(task, []))
    Error(_) -> errors.internal_error()
  }
}

/// Delete a todo
pub fn delete(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "todo_id")
  let assert Ok(todo_id) = param.as_int

  case todo_model.delete(services.db, todo_id) {
    Ok(_) -> empty_response(status.no_content)
    Error(_) -> errors.internal_error()
  }
}

/// Toggle todo completion
pub fn toggle(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "todo_id")
  let assert Ok(todo_id) = param.as_int

  case todo_model.toggle_completed(services.db, todo_id) {
    Ok(task) -> {
      let tags = case tag_model.get_tags_for_todo(services.db, task.id) {
        Ok(t) -> t
        Error(_) -> []
      }
      html_response(status.ok, todo_view.card(task, tags))
    }
    Error(_) -> errors.internal_error()
  }
}

/// Reorder todo (update position)
pub fn reorder(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "todo_id")
  let assert Ok(todo_id) = param.as_int

  // Would need to get position from request body
  let new_position = 0

  case todo_model.update_position(services.db, todo_id, new_position) {
    Ok(_) -> empty_response(status.ok)
    Error(_) -> errors.internal_error()
  }
}

